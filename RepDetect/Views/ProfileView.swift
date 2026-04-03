import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("RepDetect iOS")
                    Text("Pose: Apple Vision · Classification: native KNN (same C core as Android)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
        }
    }
}
