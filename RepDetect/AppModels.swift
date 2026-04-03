import Foundation
import SwiftData

@Model
final class PlanItem {
    var exercise: String
    var calories: Double
    var repeatCount: Int
    var selectedDays: String
    var completed: Bool
    var timeCompleted: Int64?

    init(
        exercise: String,
        calories: Double,
        repeatCount: Int,
        selectedDays: String,
        completed: Bool = false,
        timeCompleted: Int64? = nil
    ) {
        self.exercise = exercise
        self.calories = calories
        self.repeatCount = repeatCount
        self.selectedDays = selectedDays
        self.completed = completed
        self.timeCompleted = timeCompleted
    }
}

@Model
final class WorkoutResultEntity {
    var exerciseName: String
    var repeatedCount: Int
    var confidence: Float
    var timestamp: Int64
    var calorie: Double
    var workoutTimeInMin: Double

    init(
        exerciseName: String,
        repeatedCount: Int,
        confidence: Float,
        timestamp: Int64,
        calorie: Double,
        workoutTimeInMin: Double
    ) {
        self.exerciseName = exerciseName
        self.repeatedCount = repeatedCount
        self.confidence = confidence
        self.timestamp = timestamp
        self.calorie = calorie
        self.workoutTimeInMin = workoutTimeInMin
    }
}
