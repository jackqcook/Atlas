import Foundation
import SwiftUI
import Supabase

@MainActor
final class MessagingViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var error: String?

    private let messageService = MessageService.shared
    private var realtimeChannel: RealtimeChannelV2?
    private var streamTask: Task<Void, Never>?

    func load(channelID: UUID) async {
        isLoading = true
        do {
            messages = try await messageService.fetchMessages(for: channelID)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
        await subscribeToNewMessages(channelID: channelID)
    }

    func send(content: String, channelID: UUID, senderID: UUID) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let message = try await messageService.sendMessage(content: content, channelID: channelID, senderID: senderID)
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func cleanup() {
        streamTask?.cancel()
        streamTask = nil
        Task { await realtimeChannel?.unsubscribe() }
        realtimeChannel = nil
    }

    private func subscribeToNewMessages(channelID: UUID) async {
        let (stream, channel) = await messageService.messageStream(for: channelID)
        realtimeChannel = channel
        streamTask = Task {
            for await message in stream {
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
            }
        }
    }
}
