import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query(sort: \WorkoutResultEntity.timestamp, order: .reverse) private var results: [WorkoutResultEntity]

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh-Hans")
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh-Hans")
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private var historySections: [(day: String, rows: [WorkoutResultEntity])] {
        var out: [(String, [WorkoutResultEntity])] = []
        for r in results {
            let d = Date(timeIntervalSince1970: TimeInterval(r.timestamp) / 1000.0)
            let day = Self.dayFormatter.string(from: d)
            if var last = out.last, last.0 == day {
                last.1.append(r)
                out[out.count - 1] = (day, last.1)
            } else {
                out.append((day, [r]))
            }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("RepDetect iOS")
                    Text("姿态检测：Apple Vision · 动作分类：设备端 KNN（与 Android 共用同一套 C 核心）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("在「计划 → 我的计划 → 计划详情」中开始锻炼；停止后会写入本次次数与时长。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if results.isEmpty {
                    Section("历史运动") {
                        Text("暂无记录。")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                } else {
                    ForEach(historySections.indices, id: \.self) { i in
                        let section = historySections[i]
                        Section(section.day) {
                            ForEach(section.rows, id: \.persistentModelID) { r in
                                historyRow(r)
                            }
                        }
                    }
                }
            }
            .navigationTitle("我的")
        }
    }

    @ViewBuilder
    private func historyRow(_ r: WorkoutResultEntity) -> some View {
        let when = Date(timeIntervalSince1970: TimeInterval(r.timestamp) / 1000.0)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(ExerciseDisplay.zh(englishName: r.exerciseName))
                Spacer()
                Text("\(r.repeatedCount) 次")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack {
                Text(Self.timeFormatter.string(from: when))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f 千卡 · %.1f 分钟", r.calorie, r.workoutTimeInMin))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
