import SwiftUI

struct ContentView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(0)
            WorkoutView()
                .tabItem { Label("锻炼", systemImage: "figure.strengthtraining.traditional") }
                .tag(1)
            PlanRootView()
                .tabItem { Label("计划", systemImage: "calendar") }
                .tag(2)
            ProfileView()
                .tabItem { Label("我的", systemImage: "person.fill") }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
