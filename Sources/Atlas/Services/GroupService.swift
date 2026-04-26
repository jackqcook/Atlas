import Foundation
import Supabase

final class GroupService {
    static let shared = GroupService()
    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    func fetchMyGroups(userID: UUID) async throws -> [Group] {
        let memberships: [Membership] = try await supabase
            .from("memberships")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value

        let groupIDs = memberships.map { $0.groupID.uuidString }
        guard !groupIDs.isEmpty else { return [] }

        return try await supabase
            .from("groups")
            .select()
            .in("id", values: groupIDs)
            .order("created_at")
            .execute()
            .value
    }

    func createGroup(name: String, description: String, founderID: UUID) async throws -> Group {
        let group = Group(
            id: UUID(),
            name: name,
            description: description,
            constitution: "This group was founded on \(Date().formatted(date: .abbreviated, time: .omitted)).",
            inviteCode: generateInviteCode(),
            createdAt: Date()
        )
        try await supabase.from("groups").insert(group).execute()

        let membership = Membership(
            id: UUID(),
            userID: founderID,
            groupID: group.id,
            role: .founder,
            invitedByID: nil,
            joinedAt: Date()
        )
        try await supabase.from("memberships").insert(membership).execute()

        let channels: [Channel] = [
            Channel(id: UUID(), groupID: group.id, name: "general", type: .general, createdAt: Date()),
            Channel(id: UUID(), groupID: group.id, name: "announcements", type: .announcements, createdAt: Date()),
            Channel(id: UUID(), groupID: group.id, name: "governance", type: .governance, createdAt: Date())
        ]
        try await supabase.from("channels").insert(channels).execute()

        return group
    }

    func joinGroup(inviteCode: String, userID: UUID) async throws -> Group {
        let groups: [Group] = try await supabase
            .from("groups")
            .select()
            .eq("invite_code", value: inviteCode.uppercased())
            .limit(1)
            .execute()
            .value

        guard let group = groups.first else {
            throw AppError.invalidInviteCode
        }

        let membership = Membership(
            id: UUID(),
            userID: userID,
            groupID: group.id,
            role: .initiate,
            invitedByID: nil,
            joinedAt: Date()
        )
        try await supabase.from("memberships").insert(membership).execute()
        return group
    }

    func fetchChannels(for groupID: UUID) async throws -> [Channel] {
        try await supabase
            .from("channels")
            .select()
            .eq("group_id", value: groupID)
            .order("created_at")
            .execute()
            .value
    }

    func fetchMembers(for groupID: UUID) async throws -> [(Membership, User)] {
        let memberships: [Membership] = try await supabase
            .from("memberships")
            .select()
            .eq("group_id", value: groupID)
            .order("joined_at")
            .execute()
            .value

        let userIDs = memberships.map { $0.userID.uuidString }
        let users: [User] = try await supabase
            .from("users")
            .select()
            .in("id", values: userIDs)
            .execute()
            .value

        let userMap = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        return memberships.compactMap { m in
            guard let user = userMap[m.userID] else { return nil }
            return (m, user)
        }
    }

    func updateMemberRole(_ role: Role, userID: UUID, groupID: UUID) async throws {
        try await supabase
            .from("memberships")
            .update(["role": role.rawValue])
            .eq("user_id", value: userID)
            .eq("group_id", value: groupID)
            .execute()
    }

    func myMembership(userID: UUID, groupID: UUID) async throws -> Membership? {
        let memberships: [Membership] = try await supabase
            .from("memberships")
            .select()
            .eq("user_id", value: userID)
            .eq("group_id", value: groupID)
            .limit(1)
            .execute()
            .value
        return memberships.first
    }

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }
}
