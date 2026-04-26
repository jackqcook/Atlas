import SwiftUI

private let atlasCrimson = Color(red: 0.74, green: 0.05, blue: 0.16)

struct GroupListView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(GroupViewModel.self) private var groupVM
    @Binding var selectedGroup: Group?
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var showDiscover = false
    @State private var searchText = ""
    @State private var previewGroup: Group?
    @State private var profiles: [UUID: CommunityProfileRecord] = [:]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.white.ignoresSafeArea()

                SwiftUI.Group {
                    if groupVM.isLoading && groupVM.groups.isEmpty {
                        ProgressView()
                            .tint(atlasCrimson)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        content
                    }
                }

                addButton
                    .padding(.bottom, 28)
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
        .fullScreenCover(isPresented: $showDiscover) {
            CommunityDiscoveryView(
                groups: discoverableGroups,
                profiles: profiles,
                joinedGroupIDs: Set(groupVM.groups.map(\.id)),
                selectedGroup: $selectedGroup,
                currentUserID: authVM.currentUser?.id
            )
        }
        .sheet(item: $previewGroup) { group in
            CommunityDiscoveryDetailView(
                group: group,
                profile: profiles[group.id] ?? CommunityProfileStore.shared.loadProfile(for: group),
                isJoined: Set(groupVM.groups.map(\.id)).contains(group.id),
                currentUserID: authVM.currentUser?.id
            ) { openedGroup in
                selectedGroup = openedGroup
            }
        }
        .onAppear {
            profiles = mergedProfiles
        }
        .task(id: allKnownGroups.map(\.id)) {
            profiles = mergedProfiles
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                searchBar

                if groupVM.groups.isEmpty {
                    emptyState
                } else {
                    joinedSection
                }

                if !discoverMatches.isEmpty {
                    discoverSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 36)
            .padding(.bottom, 100)
        }
    }

    private var directoryHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Communities")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.black)
                    Text("Keep your spaces close and explore what else is forming across Atlas.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(groupVM.groups.count)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(atlasCrimson)
                    Text(groupVM.groups.count == 1 ? "joined group" : "joined groups")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            atlasCrimson.opacity(0.12),
                            Color(red: 0.99, green: 0.99, blue: 0.995)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 130)
                .overlay(alignment: .leading) {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 68, height: 68)
                            Image(systemName: "person.3.sequence.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(atlasCrimson)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(groupVM.groups.isEmpty ? "Start your first community" : "Stay oriented")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.black)
                            Text(groupVM.groups.isEmpty ? "Create a space, join one, or browse clusters forming across the network." : "Use search to jump between groups or open the globe to scan the broader landscape.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.black.opacity(0.72))
                                .lineSpacing(2)
                        }
                    }
                    .padding(.horizontal, 20)
                }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search communities", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.black)

            Button {
                showDiscover = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.13))
                        .frame(width: 38, height: 38)
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color(red: 0.985, green: 0.986, blue: 0.992))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var joinedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Your spaces", subtitle: filteredJoinedGroups.isEmpty ? "No joined communities match the current search." : "Jump back into the communities you already belong to.")

            if filteredJoinedGroups.isEmpty {
                subduedMessage("Try a different search term or open the globe to browse the wider network.")
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(filteredJoinedGroups) { group in
                        Button {
                            selectedGroup = group
                        } label: {
                            GroupRowView(group: group, profile: profiles[group.id], isJoined: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Matches to explore", subtitle: "Communities you are not in yet, pulled from the broader Atlas graph.")

            LazyVStack(spacing: 14) {
                ForEach(discoverMatches) { group in
                    Button {
                        previewGroup = group
                    } label: {
                        GroupRowView(group: group, profile: profiles[group.id], isJoined: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Button("Create Community") { showCreate = true }
                    .buttonStyle(AtlasFilledButtonStyle())

                Button("Join Community") { showJoin = true }
                    .buttonStyle(AtlasOutlineButtonStyle())
            }

            subduedMessage("No communities yet. Start one, join one with an invite code, or use the globe to browse what is already forming.")
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func subduedMessage(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.985, green: 0.986, blue: 0.992))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var addButton: some View {
        Button {
            showCreate = true
        } label: {
            Circle()
                .fill(atlasCrimson)
                .frame(width: 58, height: 58)
                .shadow(color: atlasCrimson.opacity(0.30), radius: 18, y: 10)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white)
                }
        }
    }

    private var filteredJoinedGroups: [Group] {
        if trimmedSearch.isEmpty {
            return groupVM.groups
        }
        return groupVM.groups.filter(matchesSearch)
    }

    private var discoverMatches: [Group] {
        guard !trimmedSearch.isEmpty else { return [] }
        let joinedIDs = Set(groupVM.groups.map(\.id))
        return discoverableGroups.filter { !joinedIDs.contains($0.id) && matchesSearch($0) }
    }

    private func matchesSearch(_ group: Group) -> Bool {
        let profile = profiles[group.id]
        let haystack = [
            group.name,
            group.description,
            profile?.pitch ?? "",
            profile?.territory.displayName ?? "",
            profile?.focusTags.joined(separator: " ") ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        return haystack.contains(trimmedSearch)
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var allKnownGroups: [Group] {
        let merged = (groupVM.groups + groupVM.discoverableGroups + MockCommunityCatalog.groups).reduce(into: [UUID: Group]()) { partialResult, group in
            partialResult[group.id] = group
        }
        return merged.values.sorted { $0.createdAt < $1.createdAt }
    }

    private var mergedProfiles: [UUID: CommunityProfileRecord] {
        var loaded = CommunityProfileStore.shared.loadProfiles(for: allKnownGroups)
        for (id, profile) in MockCommunityCatalog.profiles {
            loaded[id] = profile
        }
        return loaded
    }

    private var discoverableGroups: [Group] {
        allKnownGroups.filter { profiles[$0.id]?.isDiscoverable ?? true }
    }
}

struct GroupRowView: View {
    let group: Group
    let profile: CommunityProfileRecord?
    let isJoined: Bool

    var body: some View {
        HStack(spacing: 16) {
            CommunityArtworkView(group: group, profile: profile, size: 72, cornerRadius: 22)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(group.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)

                    if isJoined {
                        Text("Joined")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(atlasCrimson)
                            .clipShape(Capsule())
                    }
                }

                Text(displayDescription)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(profile?.territory.displayName ?? "Builders")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(atlasCrimson)

                    if let tag = profile?.focusTags.first {
                        Text("#\(tag)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
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

    private var displayDescription: String {
        if let profile, !profile.pitch.isEmpty {
            return profile.pitch
        }
        if !group.description.isEmpty {
            return group.description
        }
        return "Community workspace"
    }
}

private struct CommunityArtworkView: View {
    let group: Group
    let profile: CommunityProfileRecord?
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [atlasCrimson.opacity(0.14), atlasCrimson.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                if let data = profile?.logoImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                } else {
                    Text(String(group.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundStyle(atlasCrimson)
                }
            }
    }
}

private struct CommunityDiscoveryView: View {
    let groups: [Group]
    let profiles: [UUID: CommunityProfileRecord]
    let joinedGroupIDs: Set<UUID>
    @Binding var selectedGroup: Group?
    let currentUserID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var previewGroup: Group?
    @State private var selectedMapGroupID: UUID?

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.10, green: 0.105, blue: 0.115)
                .ignoresSafeArea()

            CommunityTerritoryMapView(
                groups: filteredGroups,
                profiles: profiles,
                selectedGroupID: $selectedMapGroupID
            )
            .ignoresSafeArea()

            // Fade the bottom of the map into the cards area
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.90)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 320)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }

            // X button + search bar overlaid at the top
            VStack(spacing: 14) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                    TextField("Search the network", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .tint(.white)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Single spotlight card for the selected community
            VStack(spacing: 0) {
                Spacer()
                if let spotGroup = filteredGroups.first(where: { $0.id == selectedMapGroupID }) ?? filteredGroups.first {
                    Button { previewGroup = spotGroup } label: {
                        HStack(spacing: 14) {
                            CommunityArtworkView(group: spotGroup, profile: profiles[spotGroup.id], size: 54, cornerRadius: 16)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(spotGroup.name)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                let desc = profiles[spotGroup.id]?.pitch ?? spotGroup.description
                                if !desc.isEmpty {
                                    Text(desc)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.52))
                                        .lineLimit(1)
                                }
                                if let territory = profiles[spotGroup.id]?.territory {
                                    Text(territory.displayName)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(spotlightTerritoryColor(territory))
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.32))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id(spotGroup.id)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedMapGroupID)
                }
            }
        }
        .sheet(item: $previewGroup) { group in
            CommunityDiscoveryDetailView(
                group: group,
                profile: profiles[group.id] ?? CommunityProfileStore.shared.loadProfile(for: group),
                isJoined: joinedGroupIDs.contains(group.id),
                currentUserID: currentUserID
            ) { openedGroup in
                selectedGroup = openedGroup
                dismiss()
            }
        }
        .onAppear {
            selectedMapGroupID = filteredGroups.first?.id
        }
        .onChange(of: filteredGroups.map(\.id)) { _, ids in
            if !ids.contains(selectedMapGroupID ?? UUID()) {
                selectedMapGroupID = ids.first
            }
        }
    }

    private var filteredGroups: [Group] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return groups }
        return groups.filter { group in
            let profile = profiles[group.id]
            let haystack = [
                group.name,
                group.description,
                profile?.pitch ?? "",
                profile?.territory.displayName ?? "",
                profile?.focusTags.joined(separator: " ") ?? ""
            ]
            .joined(separator: " ")
            .lowercased()
            return haystack.contains(trimmed)
        }
    }

    private func spotlightTerritoryColor(_ territory: CommunityTerritory) -> Color {
        switch territory {
        case .builders: return Color(red: 0.30, green: 0.80, blue: 0.45)
        case .local: return Color(red: 0.65, green: 0.70, blue: 0.85)
        case .ideas: return Color(red: 0.75, green: 0.80, blue: 0.95)
        case .culture: return Color(red: 0.90, green: 0.72, blue: 0.55)
        case .growth: return Color(red: 0.25, green: 0.78, blue: 0.52)
        }
    }
}

private struct CommunityDiscoveryDetailView: View {
    let group: Group
    let profile: CommunityProfileRecord
    let isJoined: Bool
    let currentUserID: UUID?
    let onOpen: (Group) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hasRequested = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        CommunityArtworkView(group: group, profile: profile, size: 86, cornerRadius: 24)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.black)
                            Text(profile.territory.displayName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(atlasCrimson)
                            Text(profile.pitch.isEmpty ? group.description : profile.pitch)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !profile.focusTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(profile.focusTags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(atlasCrimson)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(atlasCrimson.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("About")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                        Text(group.description.isEmpty ? "This community has not written a longer description yet." : group.description)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.black.opacity(0.8))
                            .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Treasury")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                        Text("Coming soon")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(atlasCrimson)
                    }

                    VStack(spacing: 12) {
                        if isJoined {
                            Button("Open Community") {
                                onOpen(group)
                            }
                            .buttonStyle(AtlasFilledButtonStyle())
                        } else {
                            Button(hasRequested ? "Request Sent" : "Request to Join") {
                                if let currentUserID {
                                    CommunityProfileStore.shared.setRequestedJoin(true, userID: currentUserID, groupID: group.id)
                                    hasRequested = true
                                }
                            }
                            .buttonStyle(AtlasFilledButtonStyle())
                            .disabled(hasRequested || currentUserID == nil)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(atlasCrimson)
                }
            }
            .onAppear {
                if let currentUserID {
                    hasRequested = CommunityProfileStore.shared.hasRequestedJoin(userID: currentUserID, groupID: group.id)
                }
            }
        }
    }
}

private struct CommunityTerritoryMapView: View {
    let groups: [Group]
    let profiles: [UUID: CommunityProfileRecord]
    @Binding var selectedGroupID: UUID?
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var lastHapticTranslation: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let nodes = layoutNodes(in: geo.size)

            ZStack(alignment: .topLeading) {
                // Star field
                ForEach(0..<42, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(i.isMultiple(of: 3) ? 0.15 : 0.07))
                        .frame(width: CGFloat(1 + (i % 3)), height: CGFloat(1 + (i % 3)))
                        .position(
                            x: CGFloat((i * 79) % 397) / 397 * geo.size.width,
                            y: CGFloat((i * 131) % 719) / 719 * geo.size.height
                        )
                }

                // Edges between nodes in the same territory
                ForEach(edgePairs(from: nodes), id: \.id) { edge in
                    Path { path in
                        path.move(to: edge.from)
                        path.addLine(to: edge.to)
                    }
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
                }

                // Territory region labels
                ForEach(territoryLabels(in: geo.size), id: \.title) { label in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white.opacity(0.88))
                        Text(label.subtitle)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                    .position(label.position)
                }

                // Community nodes
                ForEach(nodes) { node in
                    let isSelected = node.group.id == selectedGroupID
                    ZStack {
                        Circle()
                            .fill(nodeColor(node.profile.territory).opacity(0.20))
                            .frame(width: isSelected ? 36 : 18, height: isSelected ? 36 : 18)
                            .blur(radius: 7)
                        Circle()
                            .fill(isSelected ? Color.white : nodeColor(node.profile.territory))
                            .frame(width: isSelected ? 20 : 11, height: isSelected ? 20 : 11)
                            .overlay {
                                if isSelected {
                                    Circle().stroke(nodeColor(node.profile.territory), lineWidth: 3.5)
                                }
                            }
                            .shadow(color: nodeColor(node.profile.territory).opacity(0.7), radius: isSelected ? 12 : 4)
                    }
                    .position(node.position)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            selectedGroupID = node.group.id
                        }
                        AtlasHaptics.selection()
                    }
                }
            }
            .scaleEffect(zoom, anchor: .center)
            .offset(panOffset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        panOffset = CGSize(
                            width: lastPanOffset.width + value.translation.width,
                            height: lastPanOffset.height + value.translation.height
                        )
                        let dx = value.translation.width - lastHapticTranslation.width
                        let dy = value.translation.height - lastHapticTranslation.height
                        if hypot(dx, dy) > 40 {
                            AtlasHaptics.light()
                            lastHapticTranslation = value.translation
                        }
                        updateNearest(nodes: nodes, viewport: geo.size)
                    }
                    .onEnded { _ in
                        lastPanOffset = panOffset
                        lastHapticTranslation = .zero
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        zoom = min(max(lastZoom * value.magnification, 0.35), 3.5)
                    }
                    .onEnded { _ in
                        lastZoom = zoom
                    }
            )
            .clipped()
            .onAppear {
                if selectedGroupID == nil {
                    selectedGroupID = groups.first?.id
                }
            }
        }
    }

    private func updateNearest(nodes: [CommunityTerritoryNode], viewport: CGSize) {
        // Find the node closest to the viewport center in canvas space
        let cx = (viewport.width / 2 - panOffset.width) / zoom
        let cy = (viewport.height / 2 - panOffset.height) / zoom
        let nearest = nodes.min {
            hypot($0.position.x - cx, $0.position.y - cy) <
            hypot($1.position.x - cx, $1.position.y - cy)
        }
        if nearest?.group.id != selectedGroupID {
            selectedGroupID = nearest?.group.id
        }
    }

    private func layoutNodes(in size: CGSize) -> [CommunityTerritoryNode] {
        let centers: [CommunityTerritory: CGPoint] = [
            .builders: CGPoint(x: size.width * 0.20, y: size.height * 0.26),
            .local: CGPoint(x: size.width * 0.22, y: size.height * 0.72),
            .ideas: CGPoint(x: size.width * 0.58, y: size.height * 0.24),
            .culture: CGPoint(x: size.width * 0.77, y: size.height * 0.70),
            .growth: CGPoint(x: size.width * 0.58, y: size.height * 0.58)
        ]

        let grouped = Dictionary(grouping: groups) { profiles[$0.id]?.territory ?? .builders }
        var nodes: [CommunityTerritoryNode] = []

        for territory in CommunityTerritory.allCases {
            let territoryGroups = grouped[territory, default: []]
            let center = centers[territory] ?? CGPoint(x: size.width * 0.5, y: size.height * 0.5)

            for (index, group) in territoryGroups.enumerated() {
                let angle = (Double(index) / Double(max(territoryGroups.count, 1))) * Double.pi * 2
                let radius = CGFloat(54 + (index % 5) * 24)
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                let profile = profiles[group.id] ?? CommunityProfileStore.shared.loadProfile(for: group)
                nodes.append(CommunityTerritoryNode(group: group, profile: profile, position: point))
            }
        }

        return nodes
    }

    private func edgePairs(from nodes: [CommunityTerritoryNode]) -> [CommunityTerritoryEdge] {
        let grouped = Dictionary(grouping: nodes, by: { $0.profile.territory })
        var edges: [CommunityTerritoryEdge] = []

        for territory in CommunityTerritory.allCases {
            let list = grouped[territory, default: []]
            guard let first = list.first else { continue }
            for node in list.dropFirst() {
                edges.append(CommunityTerritoryEdge(from: first.position, to: node.position))
            }
        }

        return edges
    }

    private func territoryLabels(in size: CGSize) -> [CommunityTerritoryLabel] {
        [
            .init(title: "Builders", subtitle: "products, startups, operators", position: CGPoint(x: size.width * 0.18, y: size.height * 0.13)),
            .init(title: "Local", subtitle: "cities, campuses, regions", position: CGPoint(x: size.width * 0.18, y: size.height * 0.58)),
            .init(title: "Ideas", subtitle: "research, learning, science", position: CGPoint(x: size.width * 0.54, y: size.height * 0.11)),
            .init(title: "Growth", subtitle: "health, reflection, momentum", position: CGPoint(x: size.width * 0.52, y: size.height * 0.44)),
            .init(title: "Culture", subtitle: "food, art, books, media", position: CGPoint(x: size.width * 0.73, y: size.height * 0.57))
        ]
    }

    private func nodeColor(_ territory: CommunityTerritory) -> Color {
        switch territory {
        case .builders: return Color(red: 0.25, green: 0.75, blue: 0.36)
        case .local: return Color(red: 0.70, green: 0.72, blue: 0.77)
        case .ideas: return Color(red: 0.84, green: 0.84, blue: 0.86)
        case .culture: return Color(red: 0.78, green: 0.80, blue: 0.84)
        case .growth: return Color(red: 0.18, green: 0.65, blue: 0.40)
        }
    }
}

private struct CommunityTerritoryLabel {
    let title: String
    let subtitle: String
    let position: CGPoint
}

private struct CommunityTerritoryNode: Identifiable {
    let group: Group
    let profile: CommunityProfileRecord
    let position: CGPoint
    var id: UUID { group.id }
}

private struct CommunityTerritoryEdge: Identifiable {
    let id = UUID()
    let from: CGPoint
    let to: CGPoint
}

private enum AtlasHaptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

private enum MockCommunityCatalog {
    static let groups: [Group] = [
        group("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE001", "Founders Row", "A dense builder community for startup operators, product people, and engineers.", 12),
        group("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE002", "Wasatch Builders", "A local Utah cluster for people shipping software and ambitious projects.", 14),
        group("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE003", "Campus Labs", "Students and researchers turning academic ideas into working products.", 18),
        group("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE004", "Neighborhood Commons", "A local civic space for neighborhood leaders, events, and collaboration.", 9),
        group("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE005", "Provo Creators", "A culture-heavy community for makers, artists, writers, and event organizers.", 10),
        group("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE006", "Deep Thinkers Guild", "People trading ideas across economics, philosophy, science, and history.", 8),
        group("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE007", "Health Stack", "Builders and coaches focused on training, wellness, and personal systems.", 11),
        group("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE008", "Bookhouse", "A reading network for serious readers, essayists, and discussion-heavy salons.", 7),
        group("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE009", "AI Frontier", "Researchers and operators exploring practical AI deployment.", 16),
        group("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE010", "City Sports Club", "Pickup runs, watch parties, and sports-centered local community.", 6),
        group("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE011", "Design Signal", "A space for visual thinkers, brand builders, and product designers.", 13),
        group("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE012", "Quiet Ambition", "A reflection-oriented group for goals, accountability, and long-horizon growth.", 15)
    ]

    static let profiles: [UUID: CommunityProfileRecord] = Dictionary(uniqueKeysWithValues: [
        profile("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE001", .builders, "High-signal founders swapping tactics, introductions, and early momentum.", ["startups", "operators", "product"]),
        profile("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE002", .local, "A regional builder network with Utah roots and strong in-person energy.", ["utah", "local", "builders"]),
        profile("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE003", .ideas, "Students testing serious ideas in public and building around them.", ["research", "students", "campus"]),
        profile("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE004", .local, "Neighborhood leaders coordinating mutual aid, civic projects, and events.", ["city", "civic", "neighbors"]),
        profile("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE005", .culture, "Artists, hosts, and organizers building a more alive local scene.", ["art", "events", "music"]),
        profile("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE006", .ideas, "A serious space for theory, synthesis, and difficult conversations.", ["philosophy", "science", "history"]),
        profile("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE007", .growth, "Health, fitness, sleep, and mindset systems for people with ambition.", ["fitness", "wellness", "discipline"]),
        profile("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE008", .culture, "Books, essays, salons, and thoughtful conversation.", ["books", "writing", "salon"]),
        profile("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE009", .builders, "Applied AI builders working at the edge of what is useful now.", ["ai", "research", "product"]),
        profile("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE010", .local, "Sports-centered local energy with real-world meetups and recurring events.", ["sports", "events", "local"]),
        profile("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE011", .culture, "Design systems, visual taste, brand worlds, and product craft.", ["design", "brand", "taste"]),
        profile("7D13E4D9-6D85-4D8C-9434-4D0D7E4AE012", .growth, "Goal-setting, reflection, and the long arc of becoming more capable.", ["goals", "reflection", "growth"])
    ])

    private static func group(_ id: String, _ name: String, _ description: String, _ daysAgo: Int) -> Group {
        Group(
            id: UUID(uuidString: id)!,
            name: name,
            description: description,
            constitution: "",
            inviteCode: String(name.prefix(4)).uppercased() + "2026",
            createdAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        )
    }

    private static func profile(_ id: String, _ territory: CommunityTerritory, _ pitch: String, _ tags: [String]) -> (UUID, CommunityProfileRecord) {
        let uuid = UUID(uuidString: id)!
        return (
            uuid,
            CommunityProfileRecord(
                groupID: uuid,
                territory: territory,
                pitch: pitch,
                focusTags: tags,
                donationURL: "",
                isDiscoverable: true,
                logoImageData: nil
            )
        )
    }
}

struct AtlasFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
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
            .font(.system(size: 18, weight: .bold))
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
