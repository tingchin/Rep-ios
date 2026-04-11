import SwiftData
import SwiftUI

/// 从「计划详情」进入，仅针对当前这一条未完成计划做检测与计数。
struct WorkoutView: View {
    var focusedPlan: PlanItem

    @Environment(\.modelContext) private var context

    @StateObject private var camera = PoseSessionController()
    @State private var knnBridge: PoseClassifierBridge?
    @State private var jumpBridge: PoseClassifierBridge?
    @State private var started = false
    @State private var completionNotice: String?
    @State private var isPreparingModels = false
    @State private var sessionStartDate: Date?

    private var plansForSession: [PlanItem] {
        if focusedPlan.completed { return [] }
        return [focusedPlan]
    }

    var body: some View {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text(camera.overlayText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.45))
                    .padding()
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)

            VStack(spacing: 8) {
                if plansForSession.isEmpty {
                    Text("该计划已完成，请返回计划页。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                if let error = camera.errorMessage {
                    Text(error).foregroundStyle(.red)
                }

                if let notice = completionNotice {
                    Text(notice)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                }

                if started, !plansForSession.isEmpty {
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
                        ForEach(plansForSession, id: \.persistentModelID) { plan in
                            if let key = ExerciseClassifierKey.key(forExerciseName: plan.exercise) {
                                let cur = camera.postureResults[key]?.repetitions ?? 0
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(plan.displayTitle)
                                        Text(ExerciseDisplay.zh(englishName: plan.exercise))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
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
                    .disabled(!started && isPreparingModels || plansForSession.isEmpty)
                }
            }
            .padding(.bottom, 8)
        }
        .navigationTitle(focusedPlan.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(camera.$postureResults) { results in
            tryCompletePlansIfNeeded(from: results)
        }
    }

    @MainActor
    private func toggleSession() async {
        if started {
            persistSessionResultsIfNeeded()
            camera.stop()
            camera.configure(knn: nil, jump: nil, allowedKeys: [], bridgesLoading: false)
            started = false
            completionNotice = nil
            knnBridge = nil
            jumpBridge = nil
            isPreparingModels = false
            sessionStartDate = nil
            return
        }

        camera.errorMessage = nil
        completionNotice = nil
        let names = plansForSession.map(\.exercise)
        guard !names.isEmpty else {
            camera.errorMessage = "当前计划无效或已完成。"
            return
        }
        let allowed = ExerciseClassifierKey.allowedKeys(forPlanExerciseNames: names)

        camera.configure(knn: nil, jump: nil, allowedKeys: allowed, bridgesLoading: true)
        camera.start()
        started = true
        isPreparingModels = true
        sessionStartDate = Date()

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

    private func persistSessionResultsIfNeeded() {
        guard let start = sessionStartDate else { return }
        let end = Date()
        let durationMin = max(end.timeIntervalSince(start) / 60.0, 0.01)
        for plan in plansForSession {
            guard let key = ExerciseClassifierKey.key(forExerciseName: plan.exercise) else { continue }
            let reps = camera.postureResults[key]?.repetitions ?? 0
            let conf = camera.postureResults[key]?.confidence ?? 0
            let perRepCal = ExerciseCatalog.exercises.first { $0.name == plan.exercise }?.calorie ?? 3
            let estCal = Double(reps) * perRepCal * 0.12
            let entity = WorkoutResultEntity(
                exerciseName: plan.exercise,
                repeatedCount: reps,
                confidence: conf,
                timestamp: Int64(end.timeIntervalSince1970 * 1000),
                calorie: estCal,
                workoutTimeInMin: durationMin
            )
            context.insert(entity)
        }
        try? context.save()
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

        for plan in plansForSession {
            guard let key = ExerciseClassifierKey.key(forExerciseName: plan.exercise) else { continue }
            guard let reps = results[key]?.repetitions, reps >= plan.repeatCount else { continue }
            plan.completed = true
            plan.timeCompleted = now
            completedNames.append(plan.displayTitle)
        }

        if !completedNames.isEmpty {
            try? context.save()
            completionNotice = "\(completedNames.joined(separator: "、")) 已达标，对应计划已标记完成"
        }
    }
}
