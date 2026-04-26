import SwiftUI

struct GroupListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var groupVM: GroupViewModel
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        NavigationStack {
            Group {
                if groupVM.isLoading && groupVM.groups.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if groupVM.groups.isEmpty {
                    emptyState
                } else {
                    groupList
                }
            }
            .navigationTitle("Atlas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Create Group", systemImage: "plus") { showCreate = true }
                        Button("Join with Code", systemImage: "arrow.right.circle") { showJoin = true }
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateGroupView()
                .environmentObject(authVM)
                .environmentObject(groupVM)
        }
        .sheet(isPresented: $showJoin) {
            JoinGroupView()
                .environmentObject(authVM)
                .environmentObject(groupVM)
        }
    }

    private var groupList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(groupVM.groups) { group in
                    NavigationLink(destination: GroupDetailView(group: group)) {
                        GroupRowView(group: group)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            VStack(spacing: 6) {
                Text("No groups yet")
                    .font(.title3.weight(.semibold))
                Text("Create a new group or join one\nwith an invite code.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                Button("Create Group") { showCreate = true }
                    .buttonStyle(.borderedProminent)
                Button("Join Group") { showJoin = true }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct GroupRowView: View {
    let group: Group

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(String(group.name.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.accent)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(group.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
