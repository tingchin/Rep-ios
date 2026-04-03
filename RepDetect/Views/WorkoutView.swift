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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    if let layer = camera.previewLayer {
                        CameraPreviewRepresentable(layer: layer)
                            .frame(height: 420)
                    } else {
                        Color.black.frame(height: 420)
                    }
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

                    Button(started ? "停止" : "开始") {
                        if started {
                            camera.stop()
                            started = false
                            completionNotice = nil
                        } else {
                            camera.errorMessage = nil
                            completionNotice = nil
                            setupBridges()
                            camera.configure(
                                knn: knnBridge,
                                jump: jumpBridge,
                                allowedKeys: ExerciseClassifierKey.allowedKeys(
                                    forPlanExerciseNames: activePlans.map(\.exercise)
                                )
                            )
                            camera.start()
                            started = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .navigationTitle("锻炼")
            .onReceive(camera.$postureResults) { results in
                tryCompletePlansIfNeeded(from: results)
            }
        }
    }

    /// 仅根据当前未完成计划加载检测器：只合并这些运动所需的 CSV；跳绳与其它运动可同时启用。
    private func setupBridges() {
        knnBridge = nil
        jumpBridge = nil

        let names = activePlans.map(\.exercise)
        guard !names.isEmpty else {
            camera.errorMessage = "请先在「计划」中添加锻炼项目"
            return
        }

        let hasJump = names.contains { $0.lowercased() == "jump rope" }
        let others = names.filter { $0.lowercased() != "jump rope" }

        if hasJump {
            jumpBridge = PoseClassifierBridge.makeJumpRope()
        }

        if !others.isEmpty {
            do {
                let url = try CsvAssetCombiner.combineToDocuments(planExerciseNames: others)
                knnBridge = PoseClassifierBridge.makeKNN(csvPath: url.path, isStreamMode: true)
            } catch {
                camera.errorMessage = "合并训练数据失败：\(error.localizedDescription)"
                knnBridge = nil
            }
        }
    }

    private func tryCompletePlansIfNeeded(from results: [String: PostureResultSwift]) {
        guard started else { return }
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
