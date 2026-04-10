import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \PlanItem.exercise) private var plans: [PlanItem]
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

    /// 按日期分组（`results` 已按时间倒序，同一天内仍保持倒序）。
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
                if results.isEmpty {
                    Section("历史记录（按日期）") {
                        Text("暂无记录。在计划详情中开始锻炼，停止后会写入本次次数与时长。")
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
            .navigationTitle("首页")
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
