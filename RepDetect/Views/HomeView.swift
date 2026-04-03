import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \PlanItem.exercise) private var plans: [PlanItem]
    @Query(sort: \WorkoutResultEntity.timestamp, order: .reverse) private var results: [WorkoutResultEntity]

    var body: some View {
        NavigationStack {
            List {
                Section("Today’s plan") {
                    if plans.filter({ !$0.completed }).isEmpty {
                        Text("No active plans").foregroundStyle(.secondary)
                    } else {
                        ForEach(plans.filter { !$0.completed }, id: \.persistentModelID) { p in
                            VStack(alignment: .leading) {
                                Text(p.exercise)
                                Text("\(p.repeatCount) reps · \(p.selectedDays)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Recent activity") {
                    ForEach(results.prefix(8), id: \.persistentModelID) { r in
                        HStack {
                            Text(r.exerciseName)
                            Spacer()
                            Text("\(r.repeatedCount) reps")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("RepDetect")
        }
    }
}
