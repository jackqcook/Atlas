import Foundation
import Supabase

final class MessageService {
    static let shared = MessageService()
    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    func fetchMessages(for channelID: UUID, limit: Int = 50) async throws -> [Message] {
        if await DemoStore.shared.isEnabled {
            return await DemoStore.shared.fetchMessages(channelID: channelID, limit: limit)
        }

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
        if await DemoStore.shared.isEnabled {
            return await DemoStore.shared.sendMessage(content: content, channelID: channelID, senderID: senderID, threadID: threadID)
        }

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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "channel_id=eq.\(channelID.uuidString)"
        )
        let stream = AsyncStream<Message> { continuation in
            Task {
                for await action in changes {
                    if let message = try? action.decodeRecord(as: Message.self, decoder: decoder) {
                        continuation.yield(message)
                    }
                }
            }
        }
        try? await channel.subscribe()
        return (stream, channel)
    }
}
