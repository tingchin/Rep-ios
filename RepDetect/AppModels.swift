import Foundation
import SwiftData

@Model
final class PlanItem {
    /// 用户自定义计划名；为空串时在界面用运动中文名展示。
    var planTitle: String = ""
    var exercise: String
    var calories: Double
    var repeatCount: Int
    var selectedDays: String
    var completed: Bool
    var timeCompleted: Int64?

    init(
        planTitle: String = "",
        exercise: String,
        calories: Double,
        repeatCount: Int,
        selectedDays: String,
        completed: Bool = false,
        timeCompleted: Int64? = nil
    ) {
        self.planTitle = planTitle
        self.exercise = exercise
        self.calories = calories
        self.repeatCount = repeatCount
        self.selectedDays = selectedDays
        self.completed = completed
        self.timeCompleted = timeCompleted
    }
}

extension PlanItem {
    /// 列表 / 导航栏标题：优先自定义名称，否则用运动中文名。
    var displayTitle: String {
        let t = planTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        return ExerciseDisplay.zh(englishName: exercise)
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
