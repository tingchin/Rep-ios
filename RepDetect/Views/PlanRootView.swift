import SwiftData
import SwiftUI

struct PlanRootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlanItem.exercise) private var plans: [PlanItem]
    @State private var exerciseName = "Squat"
    @State private var reps = 10
    @State private var days = "Mon,Tue,Wed"

    private let pick = ExerciseCatalog.exercises.map(\.name)

    var body: some View {
        NavigationStack {
            Form {
                Section("Add plan") {
                    Picker("Exercise", selection: $exerciseName) {
                        ForEach(pick, id: \.self) { Text($0).tag($0) }
                    }
                    Stepper("Repetitions: \(reps)", value: $reps, in: 1...500)
                    TextField("Days (e.g. Mon,Tue)", text: $days)
                    Button("Save plan") {
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
                Section("Plans") {
                    ForEach(plans, id: \.persistentModelID) { p in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(p.exercise)
                                Text("\(p.repeatCount) reps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if p.completed {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                    }
                    .onDelete { idx in
                        idx.map { plans[$0] }.forEach(context.delete)
                        try? context.save()
                    }
                }
            }
            .navigationTitle("Plans")
        }
    }
}
