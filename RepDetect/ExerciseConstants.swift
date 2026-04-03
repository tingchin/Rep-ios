import Foundation

/// Mirrors Android `Constants.getExerciseList()` (English `name` keys for DB / classifier).
struct ExerciseDefinition: Identifiable, Hashable {
    let id: Int
    let name: String
    let nameZh: String
    let calorie: Double
    let level: String
    let levelZh: String
}

enum ExerciseCatalog {
    static let exercises: [ExerciseDefinition] = [
        ExerciseDefinition(id: 1, name: "Push up", nameZh: "俯卧撑", calorie: 3.2, level: "Intermediate", levelZh: "中级"),
        ExerciseDefinition(id: 2, name: "Lunge", nameZh: "弓步蹲", calorie: 3.0, level: "Beginner", levelZh: "初级"),
        ExerciseDefinition(id: 3, name: "Squat", nameZh: "深蹲", calorie: 3.8, level: "Beginner", levelZh: "初级"),
        ExerciseDefinition(id: 4, name: "Sit up", nameZh: "仰卧起坐", calorie: 5.0, level: "Advance", levelZh: "高级"),
        ExerciseDefinition(id: 5, name: "Chest press", nameZh: "卧推", calorie: 7.0, level: "Advance", levelZh: "高级"),
        ExerciseDefinition(id: 6, name: "Dead lift", nameZh: "硬拉", calorie: 10.0, level: "Advance", levelZh: "高级"),
        ExerciseDefinition(id: 7, name: "Shoulder press", nameZh: "肩上推举", calorie: 9.0, level: "Advance", levelZh: "高级"),
        ExerciseDefinition(id: 8, name: "Jump rope", nameZh: "跳绳", calorie: 8.0, level: "Intermediate", levelZh: "中级"),
        ExerciseDefinition(id: 9, name: "Warrior yoga", nameZh: "战士式瑜伽", calorie: 4.0, level: "Beginner", levelZh: "初级"),
        ExerciseDefinition(id: 10, name: "Tree yoga", nameZh: "树式瑜伽", calorie: 3.0, level: "Beginner", levelZh: "初级")
    ]
}

/// C / KNN class names — must match `PoseClassifierNative.POSE_CLASSES` on Android.
enum PoseClassNames {
    static let knnClasses: [String] = [
        "pushups_down", "squats", "lunges", "situp_up",
        "chestpress_down", "deadlift_down", "shoulderpress_down",
        "warrior", "tree_pose"
    ]
}

/// UI 显示用中文（数据层仍用英文 `name` / 分类器 key）。
enum ExerciseDisplay {
    static func zh(englishName: String) -> String {
        if let e = ExerciseCatalog.exercises.first(where: { $0.name == englishName }) {
            return e.nameZh
        }
        return zh(classifierKey: englishName)
    }

    private static let classifierZh: [String: String] = [
        "pushups_down": "俯卧撑",
        "squats": "深蹲",
        "lunges": "弓步蹲",
        "situp_up": "仰卧起坐",
        "chestpress_down": "卧推",
        "deadlift_down": "硬拉",
        "shoulderpress_down": "肩上推举",
        "warrior": "战士式瑜伽",
        "tree_pose": "树式瑜伽",
        "jumprope": "跳绳"
    ]

    static func zh(classifierKey: String) -> String {
        classifierZh[classifierKey] ?? classifierKey
    }
}
