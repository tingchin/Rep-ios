import SwiftData
import SwiftUI

struct WorkoutView: View {
    @Query(filter: #Predicate<PlanItem> { !$0.completed }, sort: \PlanItem.exercise) private var activePlans: [PlanItem]
    @Environment(\.modelContext) private var context

    @StateObject private var camera = PoseSessionController()
    @State private var bridge: PoseClassifierBridge?
    @State private var started = false

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

                HStack {
                    Button {
                        camera.flipCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                    }
                    .padding()

                    Button(started ? "Stop" : "Start") {
                        if started {
                            camera.stop()
                            started = false
                        } else {
                            camera.errorMessage = nil
                            setupBridge()
                            camera.configure(bridge: bridge)
                            camera.start()
                            started = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .navigationTitle("Workout")
        }
    }

    private func setupBridge() {
        let names = activePlans.map(\.exercise)
        let hasJump = names.contains { $0.lowercased() == "jump rope" }
        let others = names.filter { $0.lowercased() != "jump rope" }

        if !others.isEmpty && hasJump {
            bridge = PoseClassifierBridge.makeJumpRope()
        } else if hasJump && others.isEmpty {
            bridge = PoseClassifierBridge.makeJumpRope()
        } else if !others.isEmpty {
            do {
                let url = try CsvAssetCombiner.combineToDocuments(planExerciseNames: others)
                bridge = PoseClassifierBridge.makeKNN(csvPath: url.path, isStreamMode: true)
            } catch {
                camera.errorMessage = "CSV merge failed: \(error.localizedDescription)"
                bridge = nil
            }
        } else {
            do {
                let url = try CsvAssetCombiner.combineToDocuments(planExerciseNames: [])
                bridge = PoseClassifierBridge.makeKNN(csvPath: url.path, isStreamMode: true)
            } catch {
                camera.errorMessage = "CSV merge failed: \(error.localizedDescription)"
                bridge = nil
            }
        }
    }
}
