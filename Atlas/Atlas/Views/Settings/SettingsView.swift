import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var editingName = false
    @State private var draftName = ""
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            List {
                if let user = authVM.currentUser {
                    Section("Profile") {
                        HStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 52, height: 52)
                                .overlay {
                                    Text(String(user.displayName.prefix(1)).uppercased())
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.accentColor)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(user.phone)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Edit") {
                                draftName = user.displayName
                                editingName = true
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Build", value: "1")
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        showSignOutAlert = true
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Edit Name", isPresented: $editingName) {
                TextField("Display Name", text: $draftName)
                Button("Save") {
                    Task { await authVM.updateDisplayName(draftName) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    Task { await authVM.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need your phone number to sign back in.")
            }
        }
    }
}
