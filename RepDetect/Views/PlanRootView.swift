import SwiftData
import SwiftUI
import UIKit

/// 计划 Tab：默认展示「我的计划」，右上角进入创建页。
struct PlanRootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanItem.exercise) private var plans: [PlanItem]

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "暂无计划",
                        systemImage: "calendar.badge.plus",
                        description: Text("点击右上角「+」创建一条锻炼计划。")
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
                        .onDelete { indices in
                            indices.map { plans[$0] }.forEach(context.delete)
                            try? context.save()
                        }
                    }
                }
            }
            .navigationTitle("计划")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        CreatePlanView()
                    } label: {
                        Label("创建计划", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
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
                    .submitLabel(.done)
                    .onSubmit { dismissKeyboard() }
                Picker("运动项目", selection: $exerciseName) {
                    ForEach(pick, id: \.self) { name in
                        Text(ExerciseDisplay.zh(englishName: name)).tag(name)
                    }
                }
            }
            Section("目标") {
                HStack {
                    Text("目标次数")
                    Spacer()
                    TextField("", value: $reps, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 56)
                        .onChange(of: reps) { _, v in
                            reps = min(500, max(1, v))
                        }
                    Stepper("", value: $reps, in: 1...500)
                        .labelsHidden()
                }
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
                    dismissKeyboard()
                    dismiss()
                }
            }
        }
        .navigationTitle("创建计划")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { dismissKeyboard() }
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
