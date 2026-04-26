import Foundation
import Observation

@Observable
final class GovernanceViewModel {
    var proposals: [Proposal] = []
    var isLoading = false
    var error: String?

    private let service = GovernanceService.shared

    func load(groupID: UUID) async {
        isLoading = true
        do {
            proposals = try await service.fetchProposals(for: groupID)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createProposal(title: String, body: String, type: ProposalType, groupID: UUID, proposerID: UUID) async -> Bool {
        do {
            let proposal = try await service.createProposal(
                title: title, body: body, type: type,
                groupID: groupID, proposerID: proposerID
            )
            proposals.insert(proposal, at: 0)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func vote(on proposalID: UUID, choice: VoteChoice, voterID: UUID) async {
        do {
            try await service.castVote(proposalID: proposalID, voterID: voterID, choice: choice)
            if let idx = proposals.firstIndex(where: { $0.id == proposalID }) {
                switch choice {
                case .yes: proposals[idx].yesCount += 1
                case .no: proposals[idx].noCount += 1
                case .abstain: proposals[idx].abstainCount += 1
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
