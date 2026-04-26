import SwiftUI

struct ProposalDetailView: View {
    let proposal: Proposal
    let group: Group
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = GovernanceViewModel()
    @State private var myVote: VoteChoice?
    @State private var isVoting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(proposal.type.displayName, systemImage: proposal.type.icon)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        StatusBadge(status: proposal.status)
                    }
                    Text(proposal.title)
                        .font(.title2.weight(.bold))
                    if proposal.isOpen {
                        Label("Closes \(proposal.votingDeadline, style: .relative)", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(proposal.body)
                    .font(.body)
                    .foregroundStyle(.primary)

                Divider()

                VStack(spacing: 12) {
                    Text("Vote")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    voteBar

                    if proposal.isOpen {
                        HStack(spacing: 10) {
                            voteButton(.yes, label: "Yes", color: .green)
                            voteButton(.no, label: "No", color: .red)
                            voteButton(.abstain, label: "Abstain", color: .secondary)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Proposal")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let userID = authVM.currentUser?.id else { return }
            myVote = try? await GovernanceService.shared.myVote(
                proposalID: proposal.id, voterID: userID
            )?.choice
        }
    }

    private var voteBar: some View {
        let total = max(proposal.totalVotes, 1)
        let yesRatio = Double(proposal.yesCount) / Double(total)
        let noRatio = Double(proposal.noCount) / Double(total)

        return VStack(spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geo.size.width * yesRatio)
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: geo.size.width * noRatio)
                    Rectangle()
                        .fill(Color(.systemFill))
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 8)

            HStack {
                Label("\(proposal.yesCount) yes", systemImage: "hand.thumbsup")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                Label("\(proposal.noCount) no", systemImage: "hand.thumbsdown")
                    .font(.caption)
                    .foregroundStyle(.red)
                Spacer()
                Text("\(proposal.totalVotes) votes cast")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func voteButton(_ choice: VoteChoice, label: String, color: Color) -> some View {
        Button {
            Task {
                guard let userID = authVM.currentUser?.id else { return }
                isVoting = true
                await vm.vote(on: proposal.id, choice: choice, voterID: userID)
                myVote = choice
                isVoting = false
            }
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(myVote == choice ? color : color.opacity(0.1))
                .foregroundStyle(myVote == choice ? .white : color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isVoting)
    }
}
