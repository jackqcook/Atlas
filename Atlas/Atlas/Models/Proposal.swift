import Foundation

struct Proposal: Codable, Identifiable {
    let id: UUID
    let groupID: UUID
    let proposerID: UUID
    var title: String
    var body: String
    var type: ProposalType
    var status: ProposalStatus
    let votingDeadline: Date
    let createdAt: Date
    var yesCount: Int
    var noCount: Int
    var abstainCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case proposerID = "proposer_id"
        case title, body, type, status
        case votingDeadline = "voting_deadline"
        case createdAt = "created_at"
        case yesCount = "yes_count"
        case noCount = "no_count"
        case abstainCount = "abstain_count"
    }

    var totalVotes: Int { yesCount + noCount + abstainCount }
    var isOpen: Bool { status == .open && votingDeadline > Date() }
}

enum ProposalType: String, Codable, CaseIterable {
    case inviteMember = "invite_member"
    case removeMember = "remove_member"
    case changeRules = "change_rules"
    case general

    var displayName: String {
        switch self {
        case .inviteMember: return "Invite Member"
        case .removeMember: return "Remove Member"
        case .changeRules: return "Change Rules"
        case .general: return "General"
        }
    }

    var icon: String {
        switch self {
        case .inviteMember: return "person.badge.plus"
        case .removeMember: return "person.badge.minus"
        case .changeRules: return "doc.text"
        case .general: return "bubble.left.and.bubble.right"
        }
    }
}

enum ProposalStatus: String, Codable {
    case open, passed, rejected, expired
}

struct Vote: Codable, Identifiable {
    let id: UUID
    let proposalID: UUID
    let voterID: UUID
    var choice: VoteChoice
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case proposalID = "proposal_id"
        case voterID = "voter_id"
        case choice
        case createdAt = "created_at"
    }
}

enum VoteChoice: String, Codable {
    case yes, no, abstain
}
