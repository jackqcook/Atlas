import Foundation
import SwiftUI

@MainActor
final class GroupDetailViewModel: ObservableObject {
    @Published var channels: [Channel] = []
    @Published var members: [(Membership, User)] = []
    @Published var myMembership: Membership?
    @Published var isLoading = false
    @Published var error: String?

    private let groupService = GroupService.shared

    func load(groupID: UUID, userID: UUID) async {
        isLoading = true
        async let channelsTask = groupService.fetchChannels(for: groupID)
        async let membersTask = groupService.fetchMembers(for: groupID)
        async let myMembershipTask = groupService.myMembership(userID: userID, groupID: groupID)

        do {
            (channels, members, myMembership) = try await (channelsTask, membersTask, myMembershipTask)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func channels(ofType type: ChannelType) -> [Channel] {
        channels.filter { $0.type == type }
    }
}
