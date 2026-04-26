import SwiftUI

private let atlasWorkspaceCrimson = Color(red: 0.74, green: 0.05, blue: 0.16)

private enum WorkspaceDestination: Hashable {
    case channels
    case channel(UUID)
    case constitution
    case advisors
    case agents
    case directory
    case jobPlatform
    case treasury
    case governance
}

private struct SidebarItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let destination: WorkspaceDestination
}

struct GroupDetailView: View {
    let group: Group
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @State private var vm = GroupDetailViewModel()
    @State private var destination: WorkspaceDestination = .channels
    @State private var sidebarSelection: WorkspaceDestination = .channels
    @State private var showCreateChannel = false
    @State private var isSidebarOpen = false

    private let sidebarItems: [SidebarItem] = [
        .init(title: "Channels", subtitle: "Rooms and discussion", systemImage: "number", destination: .channels),
        .init(title: "Constitution", subtitle: "Rules and principles", systemImage: "doc.text.fill", destination: .constitution),
        .init(title: "Advisors", subtitle: "Mentors and experts", systemImage: "person.2.crop.square.stack.fill", destination: .advisors),
        .init(title: "Agents", subtitle: "Operators and workflows", systemImage: "bolt.horizontal.circle.fill", destination: .agents),
        .init(title: "Directory", subtitle: "People and groups", systemImage: "folder.fill", destination: .directory),
        .init(title: "Job Platform", subtitle: "Roles and referrals", systemImage: "briefcase.fill", destination: .jobPlatform),
        .init(title: "Treasury", subtitle: "Funds and allocations", systemImage: "banknote.fill", destination: .treasury),
        .init(title: "Governance", subtitle: "Proposals and voting", systemImage: "building.columns.fill", destination: .governance)
    ]

    var body: some View {
        ZStack(alignment: .leading) {
            mainContent

            if isSidebarOpen {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeSidebar()
                    }
            }

            sidebarDrawer
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle(isSidebarOpen ? "" : currentNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(destination.isChannel ? .hidden : .visible, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 16) {
                    if case .channel = destination {
                        Button {
                            destination = .channels
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }

                    Button {
                        toggleSidebar()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
            }

            if canCreateChannels, destination == .channels {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateChannel = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(atlasWorkspaceCrimson)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateChannel) {
            CreateChannelSheet { name, type in
                Task {
                    if let channel = await vm.createChannel(groupID: group.id, name: name, type: type) {
                        destination = .channel(channel.id)
                    }
                }
            }
        }
        .task {
            guard let userID = authVM.currentUser?.id else { return }
            await vm.load(groupID: group.id, userID: userID)
            sidebarSelection = destination
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)

                    guard vertical < 80 else { return }

                    if horizontal > 140 {
                        dismiss()
                    } else if value.startLocation.x < 24 && horizontal > 60 {
                        openSidebar()
                    } else if isSidebarOpen && horizontal < -60 {
                        closeSidebar()
                    }
                }
        )
    }

    @ViewBuilder
    private var mainContent: some View {
        switch destination {
        case .channels:
            channelsBrowser
        case .channel(let channelID):
            if let channel = vm.channels.first(where: { $0.id == channelID }) {
                channelPanel(channel)
            } else {
                channelsBrowser
            }
        case .constitution:
            featurePanel(
                title: "Constitution",
                subtitle: "Define the operating rules, mission, and norms of the community.",
                cards: [
                    ("Mission", "State what the group is for and what it is not for."),
                    ("Membership Rules", "Clarify who can join, contribute, and lead."),
                    ("Decision Process", "Document how proposals move and how authority works.")
                ]
            )
        case .governance:
            governancePanel
        case .advisors:
            featurePanel(
                title: "Advisors",
                subtitle: "Bring trusted advisors into the group and give members a place to connect with them.",
                cards: [
                    ("Office Hours", "Set recurring sessions with advisors for the whole community."),
                    ("Introductions", "Keep advisor bios, focus areas, and warm intro paths in one place."),
                    ("Requests", "Let members ask for feedback or tactical help.")
                ]
            )
        case .agents:
            featurePanel(
                title: "Agents",
                subtitle: "Create repeatable operators for recruiting, outreach, research, and member support.",
                cards: [
                    ("Workflows", "Define repeatable flows for tasks the community runs often."),
                    ("Ownership", "Assign agents to roles, teams, or recurring operational lanes."),
                    ("Automation", "Track what can be delegated and what still needs review.")
                ]
            )
        case .directory:
            featurePanel(
                title: "Directory",
                subtitle: "A clean directory for members, teams, and companies inside the community.",
                cards: [
                    ("Member List", "Browse who is inside the group and what they focus on."),
                    ("Teams", "Organize members into project groups or cohorts."),
                    ("Profiles", "Surface roles, skills, and ways to connect.")
                ]
            )
        case .jobPlatform:
            featurePanel(
                title: "Job Platform",
                subtitle: "Share opportunities and referrals without leaving the workspace.",
                cards: [
                    ("Open Roles", "Post job openings and internships for the community."),
                    ("Referrals", "Track who can make introductions."),
                    ("Hiring Board", "Keep recruiting activity in one place.")
                ]
            )
        case .treasury:
            featurePanel(
                title: "Treasury",
                subtitle: "Track community funds, budgets, and where resources are being allocated.",
                cards: [
                    ("Balance", "Keep a clear view of available resources."),
                    ("Allocations", "Record what funding has been assigned and why."),
                    ("Requests", "Manage spend proposals and reimbursement workflows.")
                ]
            )
        }
    }

    private var channelsBrowser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                    Text("\(vm.members.count) member\(vm.members.count == 1 ? "" : "s")")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                searchRow

                browserSection("Channels", channels: vm.channels(ofType: .general))
                browserSection("Announcements", channels: vm.channels(ofType: .announcements))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 120)
        }
        .background(Color.white)
    }

    private var searchRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Search channels")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color(red: 0.98, green: 0.98, blue: 0.99))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func browserSection(_ title: String, channels: [Channel]) -> some View {
        if !channels.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                ForEach(channels) { channel in
                    Button {
                        destination = .channel(channel.id)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: channel.type == .general ? "number" : channel.type.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(atlasWorkspaceCrimson)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(channel.name)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.black)
                                Text(channelRowSubtitle(for: channel))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(atlasWorkspaceCrimson)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func channelRowSubtitle(for channel: Channel) -> String {
        switch channel.type {
        case .general:
            return "Open room for ongoing discussion"
        case .announcements:
            return "Important posts and updates"
        case .governance:
            return "Decision-making and proposals"
        }
    }

    private func channelPanel(_ channel: Channel) -> some View {
        ChannelView(channel: channel, group: group)
            .environment(authVM)
            .id(channel.id)
            .background(Color.white)
    }

    private var governancePanel: some View {
        VStack(spacing: 0) {
            panelHeader(title: "Governance", subtitle: "Proposals, voting, and decisions")
            ProposalListView(group: group)
                .background(Color.white)
        }
    }

    private func featurePanel(title: String, subtitle: String, cards: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            panelHeader(title: title, subtitle: subtitle)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(cards, id: \.0) { card in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(card.0)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                            Text(card.1)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)

                            Divider()
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                    }
                }
                .padding(.bottom, 120)
            }
        }
        .background(Color.white)
    }

    private func panelHeader(title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white)
    }

    private var sidebarDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: 112)

            VStack(alignment: .leading, spacing: 14) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        isSidebarOpen = false
                    }
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(atlasWorkspaceCrimson.opacity(0.12))
                                .frame(width: 32, height: 32)

                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(atlasWorkspaceCrimson)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Back")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(atlasWorkspaceCrimson.opacity(0.8))
                            Text("All Communities")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(atlasWorkspaceCrimson.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: atlasWorkspaceCrimson.opacity(0.08), radius: 18, y: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(group.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                    Text("Community navigation")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)

            ScrollView {
                VStack(spacing: 10) {
                ForEach(sidebarItems) { item in
                    Button {
                        sidebarSelection = item.destination
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: item.systemImage)
                                    .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(activeSidebarDestination(item.destination) ? atlasWorkspaceCrimson : .black.opacity(0.72))
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.black)
                                Text(item.subtitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(atlasWorkspaceCrimson)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(activeSidebarDestination(item.destination) ? atlasWorkspaceCrimson.opacity(0.08) : Color.clear)
                        .overlay(alignment: .leading) {
                            if activeSidebarDestination(item.destination) {
                                Capsule()
                                    .fill(atlasWorkspaceCrimson)
                                    .frame(width: 4, height: 30)
                                    .padding(.leading, 6)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 12)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 120)
            }
            }

            Spacer()
        }
        .frame(width: 300)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.985, green: 0.986, blue: 0.995),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .offset(x: isSidebarOpen ? 0 : -320)
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: isSidebarOpen)
        .ignoresSafeArea()
    }

    private func activeSidebarDestination(_ value: WorkspaceDestination) -> Bool {
        switch (sidebarSelection, value) {
        case (.channels, .channels),
            (.constitution, .constitution),
            (.advisors, .advisors),
            (.agents, .agents),
            (.directory, .directory),
            (.jobPlatform, .jobPlatform),
            (.treasury, .treasury),
            (.governance, .governance):
            return true
        default:
            return false
        }
    }

    private func toggleSidebar() {
        if isSidebarOpen {
            closeSidebar()
        } else {
            openSidebar()
        }
    }

    private func openSidebar() {
        sidebarSelection = destination
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isSidebarOpen = true
        }
    }

    private func closeSidebar() {
        destination = sidebarSelection
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isSidebarOpen = false
        }
    }

    private var canCreateChannels: Bool {
        vm.myMembership?.role == .founder || vm.myMembership?.role == .council
    }

    private var isChannelSurface: Bool {
        switch destination {
        case .channels, .channel:
            return true
        default:
            return false
        }
    }

    private var currentNavigationTitle: String {
        switch destination {
        case .channel(let channelID):
            return vm.channels.first(where: { $0.id == channelID })?.name ?? group.name
        default:
            return group.name
        }
    }
}

private extension WorkspaceDestination {
    var isChannel: Bool {
        if case .channel = self {
            return true
        }
        return false
    }
}

struct CreateChannelSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (String, ChannelType) -> Void
    @State private var name = ""
    @State private var type: ChannelType = .general

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Channel")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                    Text("Create a new room inside the community.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TextField("design-lab", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(atlasWorkspaceCrimson.opacity(0.25), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Picker("Type", selection: $type) {
                    ForEach(ChannelType.allCases, id: \.self) { channelType in
                        Text(channelType.displayName).tag(channelType)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()
            }
            .padding(20)
            .background(Color.white.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(atlasWorkspaceCrimson)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(name, type)
                        dismiss()
                    }
                    .foregroundStyle(atlasWorkspaceCrimson)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
