import SwiftUI

struct JoinGroupView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var groupVM: GroupViewModel
    @Environment(\.dismiss) var dismiss
    @State private var inviteCode = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("XXXXXXXX", text: $inviteCode)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: inviteCode) { _, new in
                            inviteCode = String(new.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
                        }
                } header: {
                    Text("Invite Code")
                } footer: {
                    Text("Ask a council member for the 8-character invite code.")
                }

                if let error = groupVM.error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Join Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        Task {
                            guard let userID = authVM.currentUser?.id else { return }
                            if await groupVM.joinGroup(inviteCode: inviteCode, userID: userID) != nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(inviteCode.count < 8 || groupVM.isLoading)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
