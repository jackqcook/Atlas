import SwiftUI

struct CreateGroupView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var groupVM: GroupViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Group Name", text: $name)
                    TextField("Short description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("You'll be the Founder", systemImage: "crown")
                            .font(.footnote.weight(.medium))
                        Text("Full council authority and an invite code will be generated for you to share with members.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            guard let userID = authVM.currentUser?.id else { return }
                            if await groupVM.createGroup(
                                name: name.trimmingCharacters(in: .whitespaces),
                                description: description.trimmingCharacters(in: .whitespaces),
                                founderID: userID
                            ) != nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || groupVM.isLoading)
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if groupVM.isLoading {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    ProgressView()
                }
            }
        }
    }
}
