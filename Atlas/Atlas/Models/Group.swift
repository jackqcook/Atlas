import Foundation

struct Group: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var constitution: String
    var inviteCode: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case constitution
        case inviteCode = "invite_code"
        case createdAt = "created_at"
    }
}
