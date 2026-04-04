import SwiftData
import SwiftUI

struct WorkoutView: View {
    @Query(filter: #Predicate<PlanItem> { !$0.completed }, sort: \PlanItem.exercise) private var activePlans: [PlanItem]
    @Environment(\.modelContext) private var context

    @StateObject private var camera = PoseSessionController()
    @State private var knnBridge: PoseClassifierBridge?
    @State private var jumpBridge: PoseClassifierBridge?
    @State private var started = false
    @State private var completionNotice: String?
    @State private var isPreparingModels = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    GeometryReader { geo in
                        ZStack {
                            if let layer = camera.previewLayer {
                                CameraPreviewRepresentable(layer: layer)
                            } else {
                                Color.black
                            }
                            BodyPoseOverlayView(
                                observation: camera.lastBodyPoseObservation,
                                imageSize: camera.lastPoseImageSize,
                                isFrontCamera: camera.isUsingFrontCamera
                            )
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .frame(height: 420)

                    Text(camera.overlayText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.45))
                        .padding()
                }

                if let error = camera.errorMessage {
                    Text(error).foregroundStyle(.red).padding()
                }

                if let notice = completionNotice {
                    Text(notice)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                if started, !activePlans.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("当前计划进度")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if isPreparingModels, !camera.recognitionReady {
                            HStack {
                                ProgressView()
                                Text("正在加载识别模型，可先对准镜头")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(activePlans, id: \.persistentModelID) { plan in
                            if let key = ExerciseClassifierKey.key(forExerciseName: plan.exercise) {
                                let cur = camera.postureResults[key]?.repetitions ?? 0
                                HStack {
                                    Text(ExerciseDisplay.zh(englishName: plan.exercise))
                                    Spacer()
                                    Text("\(cur) / \(plan.repeatCount) 次")
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                HStack {
                    Button {
                        camera.flipCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                    }
                    .padding()
                    .disabled(!started)

                    Button {
                        Task { await toggleSession() }
                    } label: {
                        if !started, isPreparingModels {
                            ProgressView()
                                .padding(.horizontal, 8)
                        } else {
                            Text(started ? "停止" : "开始")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!started && isPreparingModels)
                }
                Spacer()
            }
            .navigationTitle("锻炼")
            .onReceive(camera.$postureResults) { results in
                tryCompletePlansIfNeeded(from: results)
            }
        }
    }

    @MainActor
    private func toggleSession() async {
        if started {
            camera.stop()
            camera.configure(knn: nil, jump: nil, allowedKeys: [], bridgesLoading: false)
            started = false
            completionNotice = nil
            knnBridge = nil
            jumpBridge = nil
            isPreparingModels = false
            return
        }

        camera.errorMessage = nil
        completionNotice = nil
        let names = activePlans.map(\.exercise)
        guard !names.isEmpty else {
            camera.errorMessage = "请先在「计划」中添加锻炼项目"
            return
        }
        let allowed = ExerciseClassifierKey.allowedKeys(forPlanExerciseNames: names)

        /// 先开相机 + Vision（骨骼），CSV/KNN 在后台加载，缩短「黑屏等待」。
        camera.configure(knn: nil, jump: nil, allowedKeys: allowed, bridgesLoading: true)
        camera.start()
        started = true
        isPreparingModels = true

        let built = await buildBridgesOffMainThread(planNames: names)
        isPreparingModels = false

        if let err = built.error {
            camera.errorMessage = err
            camera.configure(knn: nil, jump: nil, allowedKeys: allowed, bridgesLoading: false)
            return
        }

        knnBridge = built.knn
        jumpBridge = built.jump
        camera.configure(knn: built.knn, jump: built.jump, allowedKeys: allowed, bridgesLoading: false)
    }

    private func buildBridgesOffMainThread(planNames: [String]) async -> (knn: PoseClassifierBridge?, jump: PoseClassifierBridge?, error: String?) {
        await Task.detached(priority: .userInitiated) {
            guard !planNames.isEmpty else {
                return (nil, nil, "请先在「计划」中添加锻炼项目")
            }
            let hasJump = planNames.contains { $0.lowercased() == "jump rope" }
            let others = planNames.filter { $0.lowercased() != "jump rope" }
            var knn: PoseClassifierBridge?
            var jump: PoseClassifierBridge?
            if hasJump {
                jump = PoseClassifierBridge.makeJumpRope()
            }
            if !others.isEmpty {
                do {
                    let url = try CsvAssetCombiner.combineToDocuments(planExerciseNames: others)
                    knn = PoseClassifierBridge.makeKNN(csvPath: url.path, isStreamMode: true)
                } catch {
                    return (nil, jump, "合并训练数据失败：\(error.localizedDescription)")
                }
            }
            return (knn, jump, nil)
        }.value
    }

    private func tryCompletePlansIfNeeded(from results: [String: PostureResultSwift]) {
        guard started, camera.recognitionReady else { return }
        var completedNames: [String] = []
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        for plan in activePlans {
            guard let key = ExerciseClassifierKey.key(forExerciseName: plan.exercise) else { continue }
            guard let reps = results[key]?.repetitions, reps >= plan.repeatCount else { continue }
            plan.completed = true
            plan.timeCompleted = now
            completedNames.append(ExerciseDisplay.zh(englishName: plan.exercise))
        }

        if !completedNames.isEmpty {
            try? context.save()
            completionNotice = "\(completedNames.joined(separator: "、")) 已达标，对应计划已标记完成"
        }
    }
}
