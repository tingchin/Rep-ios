import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanItem.exercise) private var plans: [PlanItem]

    /// 今日锻炼日且未完成的计划（跨日后对已完成的计划会在 `onAppear` 中按规则重置）。
    private var todayPlans: [PlanItem] {
        plans.filter { !$0.completed && WeekdaySelection.scheduleIncludesToday($0.selectedDays) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("今日计划") {
                    if todayPlans.isEmpty {
                        Text("今日暂无进行中的计划（请检查计划的「锻炼日」是否包含今天）。")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(todayPlans, id: \.persistentModelID) { p in
                            NavigationLink {
                                PlanDetailView(plan: p)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(p.displayTitle)
                                    Text("\(ExerciseDisplay.zh(englishName: p.exercise)) · \(p.repeatCount) 次")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("首页")
            .onAppear {
                rollDailyCompletionsIfNeeded()
            }
        }
    }

    /// 非今日完成的计划，在新的一天且当天属于计划锻炼日时，重新显示为未完成。
    private func rollDailyCompletionsIfNeeded() {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: Date())
        var changed = false
        for p in plans where p.completed {
            guard let t = p.timeCompleted else { continue }
            let doneDay = cal.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(t) / 1000.0))
            guard doneDay < startToday else { continue }
            guard WeekdaySelection.scheduleIncludesToday(p.selectedDays) else { continue }
            p.completed = false
            p.timeCompleted = nil
            changed = true
        }
        if changed {
            try? context.save()
        }
    }
}
