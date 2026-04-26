import SwiftUI
import PhotosUI

private let atlasCreateCrimson = Color(red: 0.74, green: 0.05, blue: 0.16)

struct CreateGroupView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(GroupViewModel.self) private var groupVM
    @Environment(\.dismiss) var dismiss
    let onCreated: (Group) -> Void
    @State private var name = ""
    @State private var description = ""
    @State private var territory: CommunityTerritory = .builders
    @State private var donationURL = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var logoImageData: Data?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Community")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                    Text("Set up the community and Atlas will create the starter channels for you.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(atlasCreateCrimson.opacity(0.08))
                                .frame(width: 74, height: 74)

                            if let logoImageData, let image = UIImage(data: logoImageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 74, height: 74)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(atlasCreateCrimson)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Community Logo")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)
                            Text("Add a mark so the group is recognizable across Atlas.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Community Name")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(atlasCreateCrimson)
                    TextField("Neighborhood Council", text: $name)
                        .padding(14)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(atlasCreateCrimson.opacity(0.24), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Description")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(atlasCreateCrimson)
                    TextField("What is this community for?", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(14)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(atlasCreateCrimson.opacity(0.24), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Territory")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(atlasCreateCrimson)
                    Picker("Territory", selection: $territory) {
                        ForEach(CommunityTerritory.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(14)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(atlasCreateCrimson.opacity(0.24), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Donation Link")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(atlasCreateCrimson)
                    TextField("Optional treasury or donation URL", text: $donationURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(atlasCreateCrimson.opacity(0.24), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("You'll start as Founder", systemImage: "crown.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(atlasCreateCrimson)
                    Text("Atlas will generate an invite code and create the starter spaces automatically.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(atlasCreateCrimson.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let error = groupVM.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(atlasCreateCrimson)
                }

                Spacer()
            }
            .padding(20)
            .background(Color.white.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(atlasCreateCrimson)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            guard let userID = authVM.currentUser?.id else { return }
                            if let group = await groupVM.createGroup(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                                founderID: userID
                            ) {
                                let profile = CommunityProfileRecord(
                                    groupID: group.id,
                                    territory: territory,
                                    pitch: description.trimmingCharacters(in: .whitespacesAndNewlines),
                                    focusTags: [territory.displayName.lowercased()],
                                    donationURL: donationURL.trimmingCharacters(in: .whitespacesAndNewlines),
                                    isDiscoverable: true,
                                    logoImageData: logoImageData
                                )
                                CommunityProfileStore.shared.saveProfile(profile)
                                onCreated(group)
                                dismiss()
                            }
                        }
                    }
                    .foregroundStyle(atlasCreateCrimson)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || groupVM.isLoading)
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if groupVM.isLoading {
                    Color.white.opacity(0.65).ignoresSafeArea()
                    ProgressView()
                        .tint(atlasCreateCrimson)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    logoImageData = try? await newValue.loadTransferable(type: Data.self)
                }
            }
        }
    }
}
