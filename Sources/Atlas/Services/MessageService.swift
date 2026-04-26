import Foundation
import Supabase

final class MessageService {
    static let shared = MessageService()
    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    func fetchMessages(for channelID: UUID, limit: Int = 50) async throws -> [Message] {
        let messages: [Message] = try await supabase
            .from("messages")
            .select()
            .eq("channel_id", value: channelID)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return messages.reversed()
    }

    func sendMessage(content: String, channelID: UUID, senderID: UUID, threadID: UUID? = nil) async throws -> Message {
        let message = Message(
            id: UUID(),
            channelID: channelID,
            senderID: senderID,
            content: content,
            createdAt: Date(),
            threadID: threadID,
            senderName: nil
        )
        try await supabase.from("messages").insert(message).execute()
        return message
    }

    func messageStream(for channelID: UUID) async -> (AsyncStream<Message>, RealtimeChannelV2) {
        let channel = supabase.realtimeV2.channel("messages:\(channelID)")
        let stream = AsyncStream<Message> { continuation in
            Task {
                for await action in await channel.postgresChange(InsertAction.self, table: "messages", filter: "channel_id=eq.\(channelID.uuidString)") {
                    if let message = try? action.decodeRecord(as: Message.self) {
                        continuation.yield(message)
                    }
                }
            }
        }
        await channel.subscribe()
        return (stream, channel)
    }
}
