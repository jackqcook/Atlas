import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser { Spacer(minLength: 64) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 3) {
                if !isFromCurrentUser, let name = message.senderName {
                    Text(name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }

                Text(message.content)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(isFromCurrentUser ? Color.accentColor : Color(.tertiarySystemBackground))
                    .foregroundStyle(isFromCurrentUser ? .white : .primary)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 18)
                    )

                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if !isFromCurrentUser { Spacer(minLength: 64) }
        }
        .padding(.vertical, 1)
    }
}
