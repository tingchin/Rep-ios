import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("RepDetect iOS")
                    Text("姿态检测：Apple Vision · 动作分类：设备端 KNN（与 Android 共用同一套 C 核心）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("锻炼：请在「计划」中进入某条计划详情，再点「开始锻炼」打开相机。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("我的")
        }
    }
}
