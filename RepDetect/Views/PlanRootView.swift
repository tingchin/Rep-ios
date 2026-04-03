import SwiftData
import SwiftUI

struct PlanRootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanItem.exercise) private var plans: [PlanItem]
    @State private var exerciseName = "Squat"
    @State private var reps = 10
    @State private var days = "周一,周二,周三"

    private var pick: [String] {
        ExerciseCatalog.exercises.map(\.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("新建计划") {
                    Picker("运动项目", selection: $exerciseName) {
                        ForEach(pick, id: \.self) { name in
                            Text(ExerciseDisplay.zh(englishName: name)).tag(name)
                        }
                    }
                    Stepper("目标次数：\(reps)", value: $reps, in: 1...500)
                    TextField("锻炼日（例如：周一,周二）", text: $days)
                    Button("保存计划") {
                        let cal = ExerciseCatalog.exercises.first { $0.name == exerciseName }?.calorie ?? 3
                        let item = PlanItem(
                            exercise: exerciseName,
                            calories: cal,
                            repeatCount: reps,
                            selectedDays: days
                        )
                        context.insert(item)
                        try? context.save()
                    }
                }
                Section("我的计划") {
                    if plans.isEmpty {
                        Text("暂无计划，请先在上方新建并保存")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(plans, id: \.persistentModelID) { p in
                            NavigationLink {
                                PlanDetailView(plan: p)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(ExerciseDisplay.zh(englishName: p.exercise))
                                        Text("\(p.repeatCount) 次 · \(p.selectedDays)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if p.completed {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                        .onDelete { idx in
                            idx.map { plans[$0] }.forEach(context.delete)
                            try? context.save()
                        }
                    }
                }
            }
            .navigationTitle("计划")
        }
    }
}
