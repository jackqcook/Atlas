import SwiftUI

struct ChannelView: View {
    let channel: Channel
    let group: Group
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = MessagingViewModel()
    @State private var draftText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            inputBar
        }
        .navigationTitle("#\(channel.name)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load(channelID: channel.id)
        }
        .onDisappear {
            vm.cleanup()
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(vm.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: message.senderID == authVM.currentUser?.id
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message #\(channel.name)", text: $draftText, axis: .vertical)
                .lineLimit(1...6)
                .padding(.vertical, 10)
                .padding(.leading, 16)
                .focused($inputFocused)

            Button {
                let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                draftText = ""
                Task {
                    guard let userID = authVM.currentUser?.id else { return }
                    await vm.send(content: text, channelID: channel.id, senderID: userID)
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .tertiary : .accent)
            }
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.trailing, 10)
            .padding(.bottom, 8)
        }
        .background(Color(.secondarySystemBackground))
    }
}
