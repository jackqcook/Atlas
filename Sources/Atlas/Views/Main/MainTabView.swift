import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var groupVM = GroupViewModel()

    var body: some View {
        TabView {
            GroupListView()
                .tabItem { Label("Groups", systemImage: "person.3") }
                .environmentObject(groupVM)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            if let userID = authVM.currentUser?.id {
                await groupVM.loadGroups(for: userID)
            }
        }
    }
}
