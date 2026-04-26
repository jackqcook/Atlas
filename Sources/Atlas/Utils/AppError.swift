import Foundation

enum AppError: LocalizedError {
    case invalidInviteCode
    case unauthorized
    case groupNotFound
    case messageFailed

    var errorDescription: String? {
        switch self {
        case .invalidInviteCode: return "Invalid invite code. Please check and try again."
        case .unauthorized: return "You don't have permission to do that."
        case .groupNotFound: return "Group not found."
        case .messageFailed: return "Failed to send message. Please try again."
        }
    }
}
