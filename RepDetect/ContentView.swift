import SwiftUI

struct ContentView: View {
    @State private var tab = 0
    /// 离开某 Tab 时重建该 Tab 根视图，清空 `NavigationStack` 内残留页面（避免从首页进相机后切 Tab 仍回到相机）。
    @State private var homeStackID = UUID()
    @State private var planStackID = UUID()
    @State private var profileStackID = UUID()

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .id(homeStackID)
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(0)
            PlanRootView()
                .id(planStackID)
                .tabItem { Label("计划", systemImage: "calendar") }
                .tag(1)
            ProfileView()
                .id(profileStackID)
                .tabItem { Label("我的", systemImage: "person.fill") }
                .tag(2)
        }
        /// 离开某个 Tab 时重置其根视图，避免在「首页 → 计划详情 → 相机」后切到「计划」再回「首页」仍停在相机页。
        .onChange(of: tab) { oldTab, _ in
            switch oldTab {
            case 0: homeStackID = UUID()
            case 1: planStackID = UUID()
            case 2: profileStackID = UUID()
            default: break
            }
        }
    }
}

#Preview {
    ContentView()
}
