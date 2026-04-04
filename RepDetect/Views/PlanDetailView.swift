import SwiftData
import SwiftUI

/// 点击某条计划后进入，可查看/编辑并标记完成。
struct PlanDetailView: View {
    @Bindable var plan: PlanItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWeekdays: Set<Int> = []

    var body: some View {
        Form {
            Section("运动") {
                Text(ExerciseDisplay.zh(englishName: plan.exercise))
                    .font(.headline)
            }
            Section("目标") {
                Stepper("目标次数：\(plan.repeatCount)", value: $plan.repeatCount, in: 1...500)
                WeekdayMultiPicker(selectedIndices: $selectedWeekdays)
                    .onChange(of: selectedWeekdays) { _, new in
                        plan.selectedDays = WeekdaySelection.string(from: new)
                    }
                LabeledContent("预估热量（千卡）") {
                    Text(String(format: "%.1f", plan.calories))
                }
            }
            Section("状态") {
                Toggle("已完成", isOn: $plan.completed)
            }
            Section {
                Button("保存修改") {
                    plan.selectedDays = WeekdaySelection.string(from: selectedWeekdays)
                    try? context.save()
                }
                Button("删除此计划", role: .destructive) {
                    context.delete(plan)
                    try? context.save()
                    dismiss()
                }
            }
        }
        .navigationTitle("计划详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedWeekdays = WeekdaySelection.indices(from: plan.selectedDays)
        }
    }
}
