import Foundation

struct Message: Codable, Identifiable, Equatable {
    let id: UUID
    let channelID: UUID
    let senderID: UUID
    var content: String
    let createdAt: Date
    var threadID: UUID?
    var senderName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case channelID = "channel_id"
        case senderID = "sender_id"
        case content
        case createdAt = "created_at"
        case threadID = "thread_id"
        case senderName = "sender_name"
    }
}
