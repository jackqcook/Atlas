import SwiftUI

struct ProposalListView: View {
    let group: Group
    @Environment(AuthViewModel.self) private var authVM
    @State private var vm = GovernanceViewModel()
    @State private var showCreate = false

    var body: some View {
        SwiftUI.Group {
            if vm.proposals.isEmpty && !vm.isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No proposals yet")
                        .font(.title3.weight(.semibold))
                    Text("Council members and above can raise proposals for the group to vote on.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(vm.proposals) { proposal in
                    NavigationLink(destination: ProposalDetailView(proposal: proposal, group: group)) {
                        ProposalRowView(proposal: proposal)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await vm.load(groupID: group.id)
        }
        .sheet(isPresented: $showCreate) {
            CreateProposalView(group: group)
                .environment(authVM)
                .environment(vm)
        }
    }
}

struct ProposalRowView: View {
    let proposal: Proposal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(proposal.type.displayName, systemImage: proposal.type.icon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                StatusBadge(status: proposal.status)
            }
            Text(proposal.title)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(2)
            HStack {
                Text("\(proposal.yesCount) yes · \(proposal.noCount) no")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if proposal.isOpen {
                    Text("Closes \(proposal.votingDeadline, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: ProposalStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .open: return .blue
        case .passed: return .green
        case .rejected: return .red
        case .expired: return .secondary
        }
    }
}
