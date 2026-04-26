import Foundation
import Observation

@Observable
final class GroupDetailViewModel {
    var channels: [Channel] = []
    var members: [(Membership, User)] = []
    var myMembership: Membership?
    var isLoading = false
    var error: String?

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

    func createChannel(groupID: UUID, name: String, type: ChannelType) async -> Channel? {
        isLoading = true
        error = nil
        do {
            let channel = try await groupService.createChannel(groupID: groupID, name: name, type: type)
            channels.append(channel)
            channels.sort { $0.createdAt < $1.createdAt }
            isLoading = false
            return channel
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return nil
        }
    }
}
