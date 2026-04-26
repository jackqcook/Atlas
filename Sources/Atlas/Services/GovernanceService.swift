import Foundation
import Supabase

final class GovernanceService {
    static let shared = GovernanceService()
    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    func fetchProposals(for groupID: UUID) async throws -> [Proposal] {
        try await supabase
            .from("proposals")
            .select()
            .eq("group_id", value: groupID)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createProposal(
        title: String,
        body: String,
        type: ProposalType,
        groupID: UUID,
        proposerID: UUID,
        durationDays: Int = 3
    ) async throws -> Proposal {
        let proposal = Proposal(
            id: UUID(),
            groupID: groupID,
            proposerID: proposerID,
            title: title,
            body: body,
            type: type,
            status: .open,
            votingDeadline: Calendar.current.date(byAdding: .day, value: durationDays, to: Date())!,
            createdAt: Date(),
            yesCount: 0,
            noCount: 0,
            abstainCount: 0
        )
        try await supabase.from("proposals").insert(proposal).execute()
        return proposal
    }

    func castVote(proposalID: UUID, voterID: UUID, choice: VoteChoice) async throws {
        let existing: [Vote] = try await supabase
            .from("votes")
            .select()
            .eq("proposal_id", value: proposalID)
            .eq("voter_id", value: voterID)
            .limit(1)
            .execute()
            .value

        if existing.isEmpty {
            let vote = Vote(
                id: UUID(),
                proposalID: proposalID,
                voterID: voterID,
                choice: choice,
                createdAt: Date()
            )
            try await supabase.from("votes").insert(vote).execute()
        } else {
            try await supabase
                .from("votes")
                .update(["choice": choice.rawValue])
                .eq("proposal_id", value: proposalID)
                .eq("voter_id", value: voterID)
                .execute()
        }
    }

    func myVote(proposalID: UUID, voterID: UUID) async throws -> Vote? {
        let votes: [Vote] = try await supabase
            .from("votes")
            .select()
            .eq("proposal_id", value: proposalID)
            .eq("voter_id", value: voterID)
            .limit(1)
            .execute()
            .value
        return votes.first
    }
}
