import Foundation

struct Membership: Codable, Identifiable {
    let id: UUID
    let userID: UUID
    let groupID: UUID
    var role: Role
    let invitedByID: UUID?
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case groupID = "group_id"
        case role
        case invitedByID = "invited_by_id"
        case joinedAt = "joined_at"
    }
}

enum Role: String, Codable, CaseIterable {
    case initiate
    case member
    case council
    case founder

    var displayName: String {
        switch self {
        case .initiate: return "Initiate"
        case .member: return "Member"
        case .council: return "Council"
        case .founder: return "Founder"
        }
    }

    var canInvite: Bool { self == .council || self == .founder }
    var canVote: Bool { self != .initiate }
    var canManageRoles: Bool { self == .council || self == .founder }
    var canCreateProposal: Bool { self != .initiate }
}
