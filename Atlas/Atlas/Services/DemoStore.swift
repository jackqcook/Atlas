import Foundation

actor DemoStore {
    static let shared = DemoStore()

    private let enabledKey = "atlas.demoMode.enabled"
    private let userIDKey = "atlas.demoMode.userID"
    private let snapshotKey = "atlas.demoMode.snapshot"

    private var groups: [Group] = []
    private var memberships: [Membership] = []
    private var channels: [Channel] = []
    private var messages: [Message] = []
    private var proposals: [Proposal] = []
    private var votes: [Vote] = []
    private var users: [UUID: User] = [:]

    init() {
        if let snapshot = Self.readSnapshot(forKey: snapshotKey) {
            groups = snapshot.groups
            memberships = snapshot.memberships
            channels = snapshot.channels
            messages = snapshot.messages
            proposals = snapshot.proposals
            votes = snapshot.votes
            users = Dictionary(uniqueKeysWithValues: snapshot.users.map { ($0.id, $0) })
        }
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    func activateDemoUser() -> User {
        UserDefaults.standard.set(true, forKey: enabledKey)

        if let existingID = UserDefaults.standard.string(forKey: userIDKey),
           let uuid = UUID(uuidString: existingID),
           let existingUser = users[uuid] {
            return existingUser
        }

        let user = User(
            id: UUID(),
            phone: "Demo Mode",
            displayName: "Demo User",
            avatarURL: nil,
            publicKey: "",
            createdAt: Date()
        )
        users[user.id] = user
        UserDefaults.standard.set(user.id.uuidString, forKey: userIDKey)
        saveSnapshot()
        return user
    }

    func currentDemoUser() -> User? {
        guard isEnabled,
              let existingID = UserDefaults.standard.string(forKey: userIDKey),
              let uuid = UUID(uuidString: existingID) else {
            return nil
        }

        if let existingUser = users[uuid] {
            return existingUser
        }

        let user = User(
            id: uuid,
            phone: "Demo Mode",
            displayName: "Demo User",
            avatarURL: nil,
            publicKey: "",
            createdAt: Date()
        )
        users[uuid] = user
        return user
    }

    func clearDemoMode() {
        UserDefaults.standard.set(false, forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: userIDKey)
    }

    func updateDisplayName(_ name: String, userID: UUID) {
        guard var user = users[userID] else { return }
        user.displayName = name
        users[userID] = user
        saveSnapshot()
    }

    func fetchMyGroups(userID: UUID) -> [Group] {
        let groupIDs = Set(memberships.filter { $0.userID == userID }.map(\.groupID))
        return groups
            .filter { groupIDs.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func createGroup(name: String, description: String, founderID: UUID) -> Group {
        let group = Group(
            id: UUID(),
            name: name,
            description: description,
            constitution: "This community was founded on \(Date().formatted(date: .abbreviated, time: .omitted)).",
            inviteCode: generateInviteCode(),
            createdAt: Date()
        )
        groups.append(group)

        let membership = Membership(
            id: UUID(),
            userID: founderID,
            groupID: group.id,
            role: .founder,
            invitedByID: nil,
            joinedAt: Date()
        )
        memberships.append(membership)

        let defaultChannels: [Channel] = [
            Channel(id: UUID(), groupID: group.id, name: "general", type: .general, createdAt: Date()),
            Channel(id: UUID(), groupID: group.id, name: "announcements", type: .announcements, createdAt: Date()),
            Channel(id: UUID(), groupID: group.id, name: "governance", type: .governance, createdAt: Date())
        ]
        channels.append(contentsOf: defaultChannels)
        saveSnapshot()

        return group
    }

    func joinGroup(inviteCode: String, userID: UUID) throws -> Group {
        guard let group = groups.first(where: { $0.inviteCode == inviteCode.uppercased() }) else {
            throw AppError.invalidInviteCode
        }

        if !memberships.contains(where: { $0.userID == userID && $0.groupID == group.id }) {
            memberships.append(
                Membership(
                    id: UUID(),
                    userID: userID,
                    groupID: group.id,
                    role: .initiate,
                    invitedByID: nil,
                    joinedAt: Date()
                )
            )
            saveSnapshot()
        }

        return group
    }

    func fetchChannels(groupID: UUID) -> [Channel] {
        channels
            .filter { $0.groupID == groupID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func createChannel(groupID: UUID, name: String, type: ChannelType) -> Channel {
        let sanitized = sanitizeChannelName(name)
        let channel = Channel(id: UUID(), groupID: groupID, name: sanitized, type: type, createdAt: Date())
        channels.append(channel)
        saveSnapshot()
        return channel
    }

    func fetchMembers(groupID: UUID) -> [(Membership, User)] {
        memberships
            .filter { $0.groupID == groupID }
            .sorted { $0.joinedAt < $1.joinedAt }
            .compactMap { membership in
                guard let user = users[membership.userID] else { return nil }
                return (membership, user)
            }
    }

    func myMembership(userID: UUID, groupID: UUID) -> Membership? {
        memberships.first(where: { $0.userID == userID && $0.groupID == groupID })
    }

    func fetchMessages(channelID: UUID, limit: Int = 50) -> [Message] {
        Array(messages.filter { $0.channelID == channelID }.suffix(limit))
    }

    func sendMessage(content: String, channelID: UUID, senderID: UUID, threadID: UUID? = nil) -> Message {
        let message = Message(
            id: UUID(),
            channelID: channelID,
            senderID: senderID,
            content: content,
            createdAt: Date(),
            threadID: threadID,
            senderName: users[senderID]?.displayName
        )
        messages.append(message)
        saveSnapshot()
        return message
    }

    func fetchProposals(groupID: UUID) -> [Proposal] {
        proposals
            .filter { $0.groupID == groupID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func createProposal(
        title: String,
        body: String,
        type: ProposalType,
        groupID: UUID,
        proposerID: UUID,
        durationDays: Int = 3
    ) -> Proposal {
        let proposal = Proposal(
            id: UUID(),
            groupID: groupID,
            proposerID: proposerID,
            title: title,
            body: body,
            type: type,
            status: .open,
            votingDeadline: Calendar.current.date(byAdding: .day, value: durationDays, to: Date())!,
            createdAt: Date(),
            yesCount: 0,
            noCount: 0,
            abstainCount: 0
        )
        proposals.insert(proposal, at: 0)
        saveSnapshot()
        return proposal
    }

    func castVote(proposalID: UUID, voterID: UUID, choice: VoteChoice) {
        if let existingIndex = votes.firstIndex(where: { $0.proposalID == proposalID && $0.voterID == voterID }) {
            let previousChoice = votes[existingIndex].choice
            votes[existingIndex].choice = choice
            updateProposalCounts(proposalID: proposalID, removing: previousChoice, adding: choice)
        } else {
            votes.append(Vote(id: UUID(), proposalID: proposalID, voterID: voterID, choice: choice, createdAt: Date()))
            updateProposalCounts(proposalID: proposalID, removing: nil, adding: choice)
        }
        saveSnapshot()
    }

    func myVote(proposalID: UUID, voterID: UUID) -> Vote? {
        votes.first(where: { $0.proposalID == proposalID && $0.voterID == voterID })
    }

    private func updateProposalCounts(proposalID: UUID, removing oldChoice: VoteChoice?, adding newChoice: VoteChoice) {
        guard let index = proposals.firstIndex(where: { $0.id == proposalID }) else { return }

        if let oldChoice {
            switch oldChoice {
            case .yes: proposals[index].yesCount = max(0, proposals[index].yesCount - 1)
            case .no: proposals[index].noCount = max(0, proposals[index].noCount - 1)
            case .abstain: proposals[index].abstainCount = max(0, proposals[index].abstainCount - 1)
            }
        }

        switch newChoice {
        case .yes: proposals[index].yesCount += 1
        case .no: proposals[index].noCount += 1
        case .abstain: proposals[index].abstainCount += 1
        }
    }

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }

    private func sanitizeChannelName(_ name: String) -> String {
        let lowered = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleaned = lowered.map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
        let collapsed = cleaned.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "new-channel" : trimmed
    }

    private func saveSnapshot() {
        let snapshot = DemoSnapshot(
            groups: groups,
            memberships: memberships,
            channels: channels,
            messages: messages,
            proposals: proposals,
            votes: votes,
            users: Array(users.values)
        )
        if let data = Self.encodeSnapshot(snapshot) {
            UserDefaults.standard.set(data, forKey: snapshotKey)
        }
    }

    nonisolated private static func encodeSnapshot(_ snapshot: DemoSnapshot) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(snapshot)
    }

    nonisolated private static func readSnapshot(forKey key: String) -> DemoSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DemoSnapshot.self, from: data)
    }
}

private struct DemoSnapshot: Codable, Sendable {
    var groups: [Group]
    var memberships: [Membership]
    var channels: [Channel]
    var messages: [Message]
    var proposals: [Proposal]
    var votes: [Vote]
    var users: [User]
}
