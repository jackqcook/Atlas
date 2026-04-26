import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: UUID
    let phone: String
    var displayName: String
    var avatarURL: String?
    var publicKey: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case phone
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case publicKey = "public_key"
        case createdAt = "created_at"
    }
}
