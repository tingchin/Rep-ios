import SwiftUI

/// 周一…周日 与存储字符串互转（逗号分隔，如 `周一,周三`）。
enum WeekdaySelection {
    static let labels = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

    /// 从已保存文案解析为选中的下标；无法解析时用默认周一～周三。
    static func indices(from stored: String) -> Set<Int> {
        let parts = stored.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty else { return [0, 1, 2] }
        var s = Set<Int>()
        for (i, lab) in labels.enumerated() where parts.contains(lab) {
            s.insert(i)
        }
        return s.isEmpty ? [0, 1, 2] : s
    }

    static func string(from indices: Set<Int>) -> String {
        let sorted = indices.isEmpty ? [0] : indices.sorted()
        return sorted.map { labels[$0] }.joined(separator: ",")
    }
}

/// 计划页 / 详情页共用的「锻炼日」多选。
struct WeekdayMultiPicker: View {
    @Binding var selectedIndices: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("锻炼日")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    let on = selectedIndices.contains(i)
                    Button {
                        if on {
                            selectedIndices.remove(i)
                        } else {
                            selectedIndices.insert(i)
                        }
                    } label: {
                        Text(WeekdaySelection.labels[i])
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(on ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.18))
                            .foregroundStyle(on ? Color.accentColor : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
