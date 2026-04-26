import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    let showSenderName: Bool
    let showAvatar: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isFromCurrentUser {
                Spacer(minLength: 90)
            } else {
                if showAvatar {
                    avatar
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 5) {
                if showSenderName {
                    Text(displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 6)
                }

                Text(message.content)
                    .font(.system(size: 17, weight: .regular))
                    .lineSpacing(1.5)
                    .foregroundStyle(isFromCurrentUser ? .white : .black)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(bubbleBackground)
                    .clipShape(bubbleShape)
            }
            .frame(
                maxWidth: isFromCurrentUser ? 260 : 300,
                alignment: isFromCurrentUser ? .trailing : .leading
            )
            .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)

            if isFromCurrentUser {
                EmptyView()
            } else {
                Spacer(minLength: 58)
            }
        }
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
    }

    private var displayName: String {
        if isFromCurrentUser {
            return "You"
        }
        return message.senderName ?? "Member"
    }

    private var initial: String {
        String(displayName.prefix(1)).uppercased()
    }

    private var avatar: some View {
        Circle()
            .fill(Color(red: 0.72, green: 0.78, blue: 0.94))
            .frame(width: 40, height: 40)
            .overlay {
                Text(initial)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
    }

    private var bubbleBackground: Color {
        isFromCurrentUser
            ? Color(red: 0.20, green: 0.50, blue: 0.96)
            : Color(red: 0.91, green: 0.91, blue: 0.93)
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if isFromCurrentUser {
            return UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 8,
                topTrailingRadius: 22
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 8,
                bottomTrailingRadius: 22,
                topTrailingRadius: 22
            )
        }
    }
}
