import Foundation
import Observation

@Observable
final class GroupViewModel {
    var groups: [Group] = []
    var discoverableGroups: [Group] = []
    var isLoading = false
    var error: String?
    var hasLoadedGroups = false
    var hasLoadedDiscoverableGroups = false

    private let groupService = GroupService.shared

    func loadGroups(for userID: UUID) async {
        isLoading = true
        do {
            groups = try await groupService.fetchMyGroups(userID: userID)
            hasLoadedGroups = true
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createGroup(name: String, description: String, founderID: UUID) async -> Group? {
        isLoading = true
        error = nil
        do {
            let group = try await groupService.createGroup(name: name, description: description, founderID: founderID)
            groups.append(group)
            discoverableGroups.append(group)
            isLoading = false
            return group
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return nil
        }
    }

    func joinGroup(inviteCode: String, userID: UUID) async -> Group? {
        isLoading = true
        error = nil
        do {
            let group = try await groupService.joinGroup(inviteCode: inviteCode, userID: userID)
            groups.append(group)
            isLoading = false
            return group
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return nil
        }
    }

    func loadDiscoverableGroups() async {
        do {
            discoverableGroups = try await groupService.fetchAllGroups()
            hasLoadedDiscoverableGroups = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func ensureGroupsLoaded(for userID: UUID) async {
        guard !hasLoadedGroups else { return }
        await loadGroups(for: userID)
    }

    func ensureDiscoverableGroupsLoaded() async {
        guard !hasLoadedDiscoverableGroups else { return }
        await loadDiscoverableGroups()
    }
}
