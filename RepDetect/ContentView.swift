import SwiftUI

struct ContentView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(0)
            PlanRootView()
                .tabItem { Label("计划", systemImage: "calendar") }
                .tag(1)
            ProfileView()
                .tabItem { Label("我的", systemImage: "person.fill") }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
