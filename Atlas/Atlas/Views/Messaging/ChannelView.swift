import SwiftUI

struct ChannelView: View {
    let channel: Channel
    let group: Group
    @Environment(AuthViewModel.self) private var authVM
    @State private var vm = MessagingViewModel()
    @State private var draftText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
                .overlay(Color.black.opacity(0.04))
            inputBar
        }
        .background(Color.white)
        .task(id: channel.id) {
            vm.cleanup()
            draftText = ""
            await vm.load(channelID: channel.id)
        }
        .onDisappear {
            vm.cleanup()
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(messageSections) { section in
                        VStack(alignment: .leading, spacing: 16) {
                            dateDivider(for: section.date)

                            ForEach(Array(section.messages.enumerated()), id: \.element.id) { index, message in
                                MessageBubbleView(
                                    message: message,
                                    isFromCurrentUser: message.senderID == authVM.currentUser?.id,
                                    showSenderName: shouldShowSenderName(for: index, in: section.messages),
                                    showAvatar: shouldShowAvatar(for: index, in: section.messages)
                                )
                                .id(message.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .background(Color.white)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func dateDivider(for date: Date) -> some View {
        HStack {
            Text(dateLabel(for: date))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity)
        }
    }

    private var inputBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(Color.white)
                .frame(width: 42, height: 42)
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                }
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(.secondary)
                }

            TextField("iMessage", text: $draftText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.vertical, 11)
                .padding(.horizontal, 16)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .focused($inputFocused)

            Button {
                let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                draftText = ""
                Task {
                    guard let userID = authVM.currentUser?.id else { return }
                    await vm.send(content: text, channelID: channel.id, senderID: userID)
                }
            } label: {
                Circle()
                    .fill(
                        draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.black.opacity(0.04)
                            : Color(red: 0.20, green: 0.50, blue: 0.96)
                    )
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? AnyShapeStyle(.secondary)
                                    : AnyShapeStyle(Color.white)
                            )
                    }
            }
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Color.white)
    }

    private var messageSections: [MessageSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: vm.messages) { message in
            calendar.startOfDay(for: message.createdAt)
        }

        return grouped.keys.sorted().map { date in
            MessageSection(
                date: date,
                messages: grouped[date]?.sorted(by: { $0.createdAt < $1.createdAt }) ?? []
            )
        }
    }

    private func dateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func shouldShowSenderName(for index: Int, in messages: [Message]) -> Bool {
        guard index < messages.count else { return false }
        let message = messages[index]
        guard message.senderID != authVM.currentUser?.id else { return false }
        guard index > 0 else { return true }
        return messages[index - 1].senderID != message.senderID
    }

    private func shouldShowAvatar(for index: Int, in messages: [Message]) -> Bool {
        guard index < messages.count else { return false }
        let message = messages[index]
        guard message.senderID != authVM.currentUser?.id else { return false }
        guard index < messages.count - 1 else { return true }
        return messages[index + 1].senderID != message.senderID
    }
}

private struct MessageSection: Identifiable {
    let date: Date
    let messages: [Message]

    var id: Date { date }
}
