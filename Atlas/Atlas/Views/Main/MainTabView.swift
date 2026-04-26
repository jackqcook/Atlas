import SwiftUI

struct MainTabView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var groupVM = GroupViewModel()
    @State private var selectedGroup: Group?

    var body: some View {
        TabView {
            GroupListView(selectedGroup: $selectedGroup)
                .tabItem { Label("Groups", systemImage: "person.3") }

            PersonalView()
                .tabItem { Label("Personal", systemImage: "square.stack.3d.up") }
        }
        .environment(groupVM)
        .task {
            if let userID = authVM.currentUser?.id {
                await groupVM.loadGroups(for: userID)
                await groupVM.loadDiscoverableGroups()
            }
        }
    }
}
