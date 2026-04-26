import Foundation
import SwiftUI

@MainActor
final class GroupViewModel: ObservableObject {
    @Published var groups: [Group] = []
    @Published var isLoading = false
    @Published var error: String?

    private let groupService = GroupService.shared

    func loadGroups(for userID: UUID) async {
        isLoading = true
        do {
            groups = try await groupService.fetchMyGroups(userID: userID)
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
}
