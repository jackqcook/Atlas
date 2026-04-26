import Foundation

struct Channel: Codable, Identifiable, Equatable {
    let id: UUID
    let groupID: UUID
    var name: String
    var type: ChannelType
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case name
        case type
        case createdAt = "created_at"
    }
}

enum ChannelType: String, Codable, CaseIterable {
    case general
    case announcements
    case governance

    var icon: String {
        switch self {
        case .general: return "#"
        case .announcements: return "megaphone"
        case .governance: return "building.columns"
        }
    }

    var sectionTitle: String {
        switch self {
        case .general: return "Channels"
        case .announcements: return "Announcements"
        case .governance: return "Governance"
        }
    }
}
