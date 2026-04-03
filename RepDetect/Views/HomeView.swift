import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \PlanItem.exercise) private var plans: [PlanItem]
    @Query(sort: \WorkoutResultEntity.timestamp, order: .reverse) private var results: [WorkoutResultEntity]

    var body: some View {
        NavigationStack {
            List {
                Section("今日计划") {
                    if plans.filter({ !$0.completed }).isEmpty {
                        Text("暂无进行中的计划").foregroundStyle(.secondary)
                    } else {
                        ForEach(plans.filter { !$0.completed }, id: \.persistentModelID) { p in
                            NavigationLink {
                                PlanDetailView(plan: p)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(ExerciseDisplay.zh(englishName: p.exercise))
                                    Text("\(p.repeatCount) 次 · \(p.selectedDays)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section("最近活动") {
                    ForEach(results.prefix(8), id: \.persistentModelID) { r in
                        HStack {
                            Text(ExerciseDisplay.zh(englishName: r.exerciseName))
                            Spacer()
                            Text("\(r.repeatedCount) 次")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("首页")
        }
    }
}
