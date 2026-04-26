import SwiftUI

private let atlasCrimson = Color(red: 0.74, green: 0.05, blue: 0.16)

struct GroupListView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(GroupViewModel.self) private var groupVM
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var selectedGroup: Group?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                Color.white.ignoresSafeArea()

                SwiftUI.Group {
                    if groupVM.isLoading && groupVM.groups.isEmpty {
                        ProgressView()
                            .tint(atlasCrimson)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if groupVM.groups.isEmpty {
                        emptyState
                    } else {
                        groupDirectory
                    }
                }

                addButton
                    .padding(.top, 12)
                    .padding(.trailing, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedGroup) { group in
                GroupDetailView(group: group)
                    .environment(authVM)
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateGroupView { group in
                selectedGroup = group
            }
            .environment(authVM)
            .environment(groupVM)
        }
        .sheet(isPresented: $showJoin) {
            JoinGroupView { group in
                selectedGroup = group
            }
            .environment(authVM)
            .environment(groupVM)
        }
    }

    private var groupDirectory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVStack(spacing: 14) {
                        ForEach(groupVM.groups) { group in
                            Button {
                                selectedGroup = group
                            } label: {
                                GroupRowView(group: group)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 48)
            .padding(.bottom, 36)
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                actionRow

                VStack(spacing: 18) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(atlasCrimson.opacity(0.08))
                        .frame(height: 220)
                        .overlay {
                            VStack(spacing: 16) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 84, height: 84)
                                    .overlay {
                                        Image(systemName: "person.3.fill")
                                            .font(.system(size: 32, weight: .semibold))
                                            .foregroundStyle(atlasCrimson)
                                    }

                                VStack(spacing: 8) {
                                    Text("No communities yet")
                                        .font(.system(size: 26, weight: .bold, design: .rounded))
                                        .foregroundStyle(.black)
                                    Text("Create your first community or join one with an invite code.")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 30)
                                }
                            }
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 48)
            .padding(.bottom, 36)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your communities")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
            Text("Open an existing workspace or start a new one.")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 42)
    }

    private var actionRow: some View {
        HStack(spacing: 14) {
            Button("Create Community") { showCreate = true }
                .buttonStyle(AtlasFilledButtonStyle())

            Button("Join Community") { showJoin = true }
                .buttonStyle(AtlasOutlineButtonStyle())
        }
    }

    private var addButton: some View {
        Button {
            showCreate = true
        } label: {
            Circle()
                .fill(Color.white)
                .frame(width: 58, height: 58)
                .shadow(color: atlasCrimson.opacity(0.10), radius: 18, y: 10)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(atlasCrimson)
                }
        }
    }
}

struct GroupRowView: View {
    let group: Group

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [atlasCrimson.opacity(0.14), atlasCrimson.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)
                .overlay {
                    Text(String(group.name.prefix(1)).uppercased())
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(atlasCrimson)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                Text(group.description.isEmpty ? "Community workspace" : group.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("Open workspace")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(atlasCrimson)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(atlasCrimson)
        }
        .padding(18)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(atlasCrimson.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 16, y: 8)
    }
}

struct AtlasFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(configuration.isPressed ? atlasCrimson.opacity(0.88) : atlasCrimson)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct AtlasOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white)
            .foregroundStyle(atlasCrimson)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(atlasCrimson.opacity(configuration.isPressed ? 0.4 : 0.85), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
