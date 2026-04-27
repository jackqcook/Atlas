import SwiftUI

struct MainTabView: View {
    private enum TabSelection: Hashable {
        case groups
        case personal
    }

    @Environment(AuthViewModel.self) private var authVM
    @State private var groupVM = GroupViewModel()
    @State private var selectedGroup: Group?
    @State private var selectedTab: TabSelection = .groups

    var body: some View {
        TabView(selection: $selectedTab) {
            GroupListView(selectedGroup: $selectedGroup)
                .tag(TabSelection.groups)
                .tabItem { Label("Groups", systemImage: "person.3") }

            PersonalView()
                .tag(TabSelection.personal)
                .tabItem { Label("Personal", systemImage: "square.stack.3d.up") }
        }
        .environment(groupVM)
        .task(id: selectedTab) {
            guard selectedTab == .groups, let userID = authVM.currentUser?.id else { return }
            await groupVM.ensureGroupsLoaded(for: userID)
            Task {
                await groupVM.ensureDiscoverableGroupsLoaded()
            }
        }
    }
}
