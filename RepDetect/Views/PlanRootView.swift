import SwiftData
import SwiftUI

struct PlanRootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        MyPlansListView()
                    } label: {
                        Label("我的计划", systemImage: "list.bullet.rectangle")
                    }
                    NavigationLink {
                        CreatePlanView()
                    } label: {
                        Label("创建计划", systemImage: "plus.circle")
                    }
                } footer: {
                    Text("创建时可填写计划名称；留空则列表与首页使用运动名称展示。")
                        .font(.caption)
                }
            }
            .navigationTitle("计划")
        }
    }
}

// MARK: - 我的计划

struct MyPlansListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanItem.exercise) private var plans: [PlanItem]

    var body: some View {
        Group {
            if plans.isEmpty {
                ContentUnavailableView(
                    "暂无计划",
                    systemImage: "calendar.badge.plus",
                    description: Text("在「创建计划」中添加一条锻炼安排。")
                )
            } else {
                List {
                    ForEach(plans, id: \.persistentModelID) { p in
                        NavigationLink {
                            PlanDetailView(plan: p)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(p.displayTitle)
                                    Text("\(ExerciseDisplay.zh(englishName: p.exercise)) · \(p.repeatCount) 次 · \(p.selectedDays)")
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
        .navigationTitle("我的计划")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 创建计划

struct CreatePlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var planTitle = ""
    @State private var exerciseName = "Squat"
    @State private var reps = 10
    @State private var selectedWeekdays: Set<Int> = [0, 1, 2]

    private var pick: [String] {
        ExerciseCatalog.exercises.map(\.name)
    }

    var body: some View {
        Form {
            Section("计划信息") {
                TextField("计划名称（可选）", text: $planTitle)
                Picker("运动项目", selection: $exerciseName) {
                    ForEach(pick, id: \.self) { name in
                        Text(ExerciseDisplay.zh(englishName: name)).tag(name)
                    }
                }
            }
            Section("目标") {
                Stepper("目标次数：\(reps)", value: $reps, in: 1...500)
                WeekdayMultiPicker(selectedIndices: $selectedWeekdays)
            }
            Section {
                Button("保存计划") {
                    let daysStr = WeekdaySelection.string(from: selectedWeekdays)
                    let cal = ExerciseCatalog.exercises.first { $0.name == exerciseName }?.calorie ?? 3
                    let item = PlanItem(
                        planTitle: planTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                        exercise: exerciseName,
                        calories: cal,
                        repeatCount: reps,
                        selectedDays: daysStr
                    )
                    context.insert(item)
                    try? context.save()
                    dismiss()
                }
            }
        }
        .navigationTitle("创建计划")
        .navigationBarTitleDisplayMode(.inline)
    }
}
