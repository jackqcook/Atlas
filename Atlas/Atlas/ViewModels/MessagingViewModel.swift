import Foundation
import Observation
import Supabase

@Observable
final class MessagingViewModel {
    var messages: [Message] = []
    var isLoading = false
    var error: String?

    @ObservationIgnored private var realtimeChannel: RealtimeChannelV2?
    @ObservationIgnored private var streamTask: Task<Void, Never>?

    private let messageService = MessageService.shared

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
        if await DemoStore.shared.isEnabled {
            return
        }

        let (stream, channel) = await messageService.messageStream(for: channelID)
        realtimeChannel = channel
        streamTask = Task { [weak self] in
            for await message in stream {
                if !(self?.messages.contains(where: { $0.id == message.id }) ?? false) {
                    self?.messages.append(message)
                }
            }
        }
    }
}
