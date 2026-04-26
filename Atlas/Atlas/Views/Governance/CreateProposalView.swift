import SwiftUI

struct CreateProposalView: View {
    let group: Group
    @Environment(AuthViewModel.self) private var authVM
    @Environment(GovernanceViewModel.self) private var vm
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var proposalBody = ""
    @State private var type: ProposalType = .general

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Proposal Type", selection: $type) {
                        ForEach(ProposalType.allCases, id: \.self) { t in
                            Label(t.displayName, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Describe the proposal...", text: $proposalBody, axis: .vertical)
                        .lineLimit(4...12)
                }

                Section {
                    Label("Voting will be open for 3 days. All members can vote.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Proposal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            guard let userID = authVM.currentUser?.id else { return }
                            let success = await vm.createProposal(
                                title: title.trimmingCharacters(in: .whitespaces),
                                body: proposalBody.trimmingCharacters(in: .whitespaces),
                                type: type,
                                groupID: group.id,
                                proposerID: userID
                            )
                            if success { dismiss() }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || proposalBody.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
