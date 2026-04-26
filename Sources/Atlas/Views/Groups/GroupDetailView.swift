import SwiftUI

struct GroupDetailView: View {
    let group: Group
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = GroupDetailViewModel()
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Channels").tag(0)
                Text("Members").tag(1)
                Text("Governance").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            Group {
                switch selectedTab {
                case 0: channelsTab
                case 1: membersTab
                case 2: governanceTab
                default: EmptyView()
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard let userID = authVM.currentUser?.id else { return }
            await vm.load(groupID: group.id, userID: userID)
        }
    }

    private var channelsTab: some View {
        List {
            ForEach(ChannelType.allCases, id: \.self) { type in
                let channels = vm.channels(ofType: type)
                if !channels.isEmpty {
                    Section(type.sectionTitle) {
                        ForEach(channels) { channel in
                            NavigationLink(destination: ChannelView(channel: channel, group: group)) {
                                Label {
                                    Text(channel.name)
                                        .font(.system(size: 15))
                                } icon: {
                                    Image(systemName: channel.type.icon)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var membersTab: some View {
        List(vm.members, id: \.0.id) { membership, user in
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Text(String(user.displayName.prefix(1)).uppercased())
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.accent)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.system(size: 15, weight: .medium))
                    Text(membership.role.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }

    private var governanceTab: some View {
        ProposalListView(group: group)
            .environmentObject(authVM)
    }
}
