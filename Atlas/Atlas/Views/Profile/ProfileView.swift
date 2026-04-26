import SwiftUI
import PhotosUI

private let atlasPersonalCrimson = Color(red: 0.74, green: 0.05, blue: 0.16)

struct PersonalView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var profile: UserProfileRecord?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showEditProfile = false
    @State private var editingNote: ProfileNoteCard?
    @State private var showNewNote = false
    @State private var showGrowthMap = false
    @State private var showNameEditor = false
    @State private var showSignOutAlert = false
    @State private var draftDisplayName = ""
    @State private var searchText = ""
    @State private var selectedCategory: PersonalNoteCategory?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let user = authVM.currentUser, let profile {
                    VStack(alignment: .leading, spacing: 24) {
                        topShelf(user: user, profile: profile)
                        collectionsSection(profile: profile)
                        recentsSection(profile: profile)
                        workspaceSection(profile: profile)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 42)
                }
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("Personal")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showNewNote = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(atlasPersonalCrimson)
                        }

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            if let user = authVM.currentUser, let profile {
                                avatarView(user: user, profile: profile, size: 34)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .task {
                await loadProfile()
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    await persistPhoto(from: newValue)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let profile {
                    EditPersonalProfileSheet(profile: profile) { updated in
                        Task {
                            await saveProfile(updated)
                        }
                    }
                }
            }
            .sheet(item: $editingNote) { note in
                if let profile {
                    PersonalNoteEditor(
                        note: note,
                        allNotes: profile.notes
                    ) { updated in
                        Task {
                            await saveNote(updated)
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewNote) {
                if let profile {
                    PersonalNoteEditor(
                        note: ProfileNoteCard(
                            id: UUID(),
                            title: "",
                            prompt: "Capture something worth revisiting.",
                            body: "",
                            updatedAt: Date(),
                            category: selectedCategory ?? .ideas
                        ),
                        allNotes: profile.notes,
                        isNew: true
                    ) { created in
                        Task {
                            await addNote(created)
                        }
                    }
                }
            }
            .sheet(isPresented: $showGrowthMap) {
                if let profile {
                    PersonalGraphView(profile: profile)
                }
            }
            .alert("Edit Name", isPresented: $showNameEditor) {
                TextField("Display Name", text: $draftDisplayName)
                Button("Save") {
                    Task {
                        await authVM.updateDisplayName(draftDisplayName)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    Task { await authVM.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need your phone number to sign back in outside demo mode.")
            }
        }
    }

    private func topShelf(user: User, profile: UserProfileRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(user.displayName)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                    Text("A private workspace for notes, patterns, and progress over time.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                Button {
                    showEditProfile = true
                } label: {
                    HStack(spacing: 8) {
                        avatarView(user: user, profile: profile, size: 42)
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black.opacity(0.72))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.07), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
            }

            Button {
                showGrowthMap = true
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Growth Map")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Peek into the shape of your notes, goals, and connections.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    PersonalGraphPreview(notes: filteredNotes.isEmpty ? profile.notes : filteredNotes)
                        .frame(height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(18)
                .background(Color(red: 0.12, green: 0.12, blue: 0.13))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func collectionsSection(profile: UserProfileRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Collections")

            ForEach(PersonalNoteCategory.allCases, id: \.self) { category in
                Button {
                    selectedCategory = selectedCategory == category ? nil : category
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: icon(for: category))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(selectedCategory == category ? atlasPersonalCrimson : .black)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(category.displayName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.black)
                            Text(categorySubtitle(for: category))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(atlasPersonalCrimson)
                        }

                        Spacer()

                        Text("\(notes(for: category, in: profile).count)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(selectedCategory == category ? .white : atlasPersonalCrimson)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(
                                selectedCategory == category
                                    ? atlasPersonalCrimson
                                    : atlasPersonalCrimson.opacity(0.08)
                            )
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func recentsSection(profile: UserProfileRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(selectedCategory == nil ? "Recents" : "\(selectedCategory?.displayName ?? "") Notes")

            ForEach(Array(filteredNotes.prefix(8).enumerated()), id: \.element.id) { index, note in
                Button {
                    editingNote = note
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(note.title)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(.black)
                            HStack(spacing: 8) {
                                Text(note.category.displayName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(atlasPersonalCrimson)
                                Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(index == 0 ? Color(red: 0.95, green: 0.95, blue: 0.96) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func workspaceSection(profile: UserProfileRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Profile & Settings")

            Button {
                showEditProfile = true
            } label: {
                workspaceRow(
                    title: "Edit Profile",
                    subtitle: "Photo, headline, goals, about, and website",
                    systemImage: "person.crop.circle"
                )
            }
            .buttonStyle(.plain)

            Button {
                draftDisplayName = authVM.currentUser?.displayName ?? ""
                showNameEditor = true
            } label: {
                workspaceRow(
                    title: "Edit Display Name",
                    subtitle: authVM.currentUser?.displayName ?? "Member",
                    systemImage: "pencil.line"
                )
            }
            .buttonStyle(.plain)

            Button {
                showSignOutAlert = true
            } label: {
                workspaceRow(
                    title: "Sign Out",
                    subtitle: "Leave Atlas on this device",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    destructive: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func workspaceRow(title: String, subtitle: String, systemImage: String, destructive: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(destructive ? atlasPersonalCrimson : .black)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(destructive ? atlasPersonalCrimson : .black)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(destructive ? atlasPersonalCrimson.opacity(0.8) : .secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
    }

    @ViewBuilder
    private func avatarView(user: User, profile: UserProfileRecord, size: CGFloat) -> some View {
        if let data = profile.avatarImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(atlasPersonalCrimson.opacity(0.12))
                .frame(width: size, height: size)
                .overlay {
                    Text(String(user.displayName.prefix(1)).uppercased())
                        .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                        .foregroundStyle(atlasPersonalCrimson)
                }
        }
    }

    private var filteredNotes: [ProfileNoteCard] {
        let base = profile?.notes.sorted(by: { $0.updatedAt > $1.updatedAt }) ?? []

        return base.filter { note in
            let categoryMatches = selectedCategory == nil || note.category == selectedCategory
            let searchMatches =
                searchText.isEmpty ||
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.body.localizedCaseInsensitiveContains(searchText) ||
                note.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            return categoryMatches && searchMatches
        }
    }

    private func notes(for category: PersonalNoteCategory, in profile: UserProfileRecord) -> [ProfileNoteCard] {
        profile.notes.filter { $0.category == category }
    }

    private func categorySubtitle(for category: PersonalNoteCategory) -> String {
        switch category {
        case .goals: return "What you are trying to move"
        case .projects: return "Active systems and workstreams"
        case .connections: return "People, follow-ups, and relationships"
        case .ideas: return "Loose concepts worth revisiting"
        case .reflections: return "Patterns, reviews, and growth"
        }
    }

    private func icon(for category: PersonalNoteCategory) -> String {
        switch category {
        case .goals: return "target"
        case .projects: return "folder.badge.plus"
        case .connections: return "person.2"
        case .ideas: return "sparkles"
        case .reflections: return "waveform.path.ecg"
        }
    }

    private func loadProfile() async {
        guard let user = authVM.currentUser else { return }
        profile = ProfileStore.shared.loadProfile(for: user)
    }

    private func saveProfile(_ updated: UserProfileRecord) async {
        ProfileStore.shared.saveProfile(updated)
        profile = updated
    }

    private func saveNote(_ note: ProfileNoteCard) async {
        guard var profile else { return }
        if let index = profile.notes.firstIndex(where: { $0.id == note.id }) {
            profile.notes[index] = note
        }
        await saveProfile(profile)
    }

    private func addNote(_ note: ProfileNoteCard) async {
        guard var profile else { return }
        profile.notes.insert(note, at: 0)
        await saveProfile(profile)
    }

    private func persistPhoto(from item: PhotosPickerItem) async {
        guard var profile,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        profile.avatarImageData = data
        await saveProfile(profile)
    }
}

private struct EditPersonalProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: UserProfileRecord
    @State private var goalsText: String
    let onSave: (UserProfileRecord) -> Void

    init(profile: UserProfileRecord, onSave: @escaping (UserProfileRecord) -> Void) {
        _draft = State(initialValue: profile)
        _goalsText = State(initialValue: profile.goals.joined(separator: ", "))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    editField("Headline", text: $draft.headline, prompt: "Engineer, founder, operator")
                    editField("Academic Focus", text: $draft.academicFocus, prompt: "Applied Math, Product, AI")
                    editField("Class / Cohort", text: $draft.classYear, prompt: "Class of 2026")
                    editField("Community Label", text: $draft.communityLabel, prompt: "BYU · sb05")
                    editField("Website", text: $draft.website, prompt: "portfolio.com")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(atlasPersonalCrimson)
                        TextEditor(text: $draft.about)
                            .frame(minHeight: 150)
                            .padding(10)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goals")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(atlasPersonalCrimson)
                        TextField("Comma separated goals", text: $goalsText)
                            .padding(14)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.985).ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(atlasPersonalCrimson)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.goals = goalsText
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        onSave(draft)
                        dismiss()
                    }
                    .foregroundStyle(atlasPersonalCrimson)
                }
            }
        }
    }

    private func editField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(atlasPersonalCrimson)
            TextField(prompt, text: text)
                .padding(14)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct PersonalNoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProfileNoteCard
    let allNotes: [ProfileNoteCard]
    let isNew: Bool
    let onSave: (ProfileNoteCard) -> Void

    init(
        note: ProfileNoteCard,
        allNotes: [ProfileNoteCard],
        isNew: Bool = false,
        onSave: @escaping (ProfileNoteCard) -> Void
    ) {
        _draft = State(initialValue: note)
        self.allNotes = allNotes
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(atlasPersonalCrimson)
                        TextField("Untitled note", text: $draft.title)
                            .padding(14)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(atlasPersonalCrimson)
                        Picker("Category", selection: $draft.category) {
                            ForEach(PersonalNoteCategory.allCases, id: \.self) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(atlasPersonalCrimson)
                        TextField("Small framing question", text: $draft.prompt)
                            .padding(14)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Body")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(atlasPersonalCrimson)
                        TextEditor(text: $draft.body)
                            .frame(minHeight: 220)
                            .padding(12)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Linked Notes")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(atlasPersonalCrimson)

                        ForEach(allNotes.filter { $0.id != draft.id }) { note in
                            Button {
                                toggleLink(note.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(note.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.black)
                                        Text(note.category.displayName)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(atlasPersonalCrimson)
                                    }

                                    Spacer()

                                    Image(systemName: draft.linkedNoteIDs.contains(note.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(draft.linkedNoteIDs.contains(note.id) ? atlasPersonalCrimson : .secondary)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.985).ignoresSafeArea())
            .navigationTitle(isNew ? "New Note" : (draft.title.isEmpty ? "Note" : draft.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(atlasPersonalCrimson)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.updatedAt = Date()
                        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            draft.title = "Untitled Note"
                        }
                        onSave(draft)
                        dismiss()
                    }
                    .foregroundStyle(atlasPersonalCrimson)
                }
            }
        }
    }

    private func toggleLink(_ id: UUID) {
        if draft.linkedNoteIDs.contains(id) {
            draft.linkedNoteIDs.removeAll { $0 == id }
        } else {
            draft.linkedNoteIDs.append(id)
        }
    }
}

private struct PersonalGraphView: View {
    let profile: UserProfileRecord
    @Environment(\.dismiss) private var dismiss
    @State private var selectedNoteID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PersonalGraphCanvas(notes: profile.notes, selectedNoteID: $selectedNoteID)
                        .frame(height: 420)
                        .background(Color(red: 0.13, green: 0.13, blue: 0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    if let selectedNote {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(selectedNote.title)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                            Text(selectedNote.category.displayName)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(atlasPersonalCrimson)
                            Text(selectedNote.body)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.black.opacity(0.82))
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.96, green: 0.965, blue: 0.97).ignoresSafeArea())
            .navigationTitle("Growth Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(atlasPersonalCrimson)
                }
            }
            .onAppear {
                selectedNoteID = profile.notes.first?.id
            }
        }
    }

    private var selectedNote: ProfileNoteCard? {
        profile.notes.first(where: { $0.id == selectedNoteID }) ?? profile.notes.first
    }
}

private struct PersonalGraphPreview: View {
    let notes: [ProfileNoteCard]

    var body: some View {
        PersonalGraphDrawing(notes: notes, selectedNoteID: .constant(nil), allowsTap: false)
    }
}

private struct PersonalGraphCanvas: View {
    let notes: [ProfileNoteCard]
    @Binding var selectedNoteID: UUID?

    var body: some View {
        PersonalGraphDrawing(notes: notes, selectedNoteID: $selectedNoteID, allowsTap: true)
    }
}

private struct PersonalGraphDrawing: View {
    let notes: [ProfileNoteCard]
    @Binding var selectedNoteID: UUID?
    let allowsTap: Bool

    var body: some View {
        GeometryReader { geometry in
            let nodes = layoutNodes(in: geometry.size)

            ZStack {
                ForEach(edgePairs(from: nodes), id: \.id) { edge in
                    Path { path in
                        path.move(to: edge.from)
                        path.addLine(to: edge.to)
                    }
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }

                ForEach(nodes) { node in
                    Circle()
                        .fill(nodeColor(node.note))
                        .frame(width: nodeDiameter(node.note), height: nodeDiameter(node.note))
                        .position(node.position)
                        .onTapGesture {
                            guard allowsTap else { return }
                            selectedNoteID = node.note.id
                        }
                }
            }
        }
    }

    private func layoutNodes(in size: CGSize) -> [PersonalGraphNode] {
        let centers: [PersonalNoteCategory: CGPoint] = [
            .goals: CGPoint(x: size.width * 0.26, y: size.height * 0.60),
            .projects: CGPoint(x: size.width * 0.62, y: size.height * 0.24),
            .connections: CGPoint(x: size.width * 0.75, y: size.height * 0.56),
            .ideas: CGPoint(x: size.width * 0.52, y: size.height * 0.56),
            .reflections: CGPoint(x: size.width * 0.34, y: size.height * 0.30)
        ]

        let grouped = Dictionary(grouping: notes, by: \.category)
        var result: [PersonalGraphNode] = []

        for category in PersonalNoteCategory.allCases {
            let items = grouped[category, default: []]
            let center = centers[category] ?? CGPoint(x: size.width * 0.5, y: size.height * 0.5)

            for (index, note) in items.enumerated() {
                let angle = (Double(index) / Double(max(items.count, 1))) * Double.pi * 2
                let radius = CGFloat(42 + (index % 4) * 18)
                let x = center.x + cos(angle) * radius
                let y = center.y + sin(angle) * radius
                result.append(PersonalGraphNode(note: note, position: CGPoint(x: x, y: y)))
            }
        }

        return result
    }

    private func edgePairs(from nodes: [PersonalGraphNode]) -> [PersonalEdge] {
        let positions = Dictionary(uniqueKeysWithValues: nodes.map { ($0.note.id, $0.position) })
        var edges: [PersonalEdge] = []

        for node in nodes {
            for linkedID in node.note.linkedNoteIDs {
                guard let linkedPosition = positions[linkedID], node.note.id.uuidString < linkedID.uuidString else { continue }
                edges.append(PersonalEdge(from: node.position, to: linkedPosition))
            }
        }

        return edges
    }

    private func nodeColor(_ note: ProfileNoteCard) -> Color {
        if note.id == selectedNoteID {
            return .white
        }

        switch note.category {
        case .goals, .reflections:
            return Color(red: 0.16, green: 0.80, blue: 0.43)
        case .projects:
            return Color.white.opacity(0.95)
        case .connections, .ideas:
            return Color.white.opacity(0.68)
        }
    }

    private func nodeDiameter(_ note: ProfileNoteCard) -> CGFloat {
        let linkBoost = CGFloat(note.linkedNoteIDs.count) * 2
        return note.id == selectedNoteID ? 22 : max(10, 12 + linkBoost)
    }
}

private struct PersonalGraphNode: Identifiable {
    let note: ProfileNoteCard
    let position: CGPoint

    var id: UUID { note.id }
}

private struct PersonalEdge: Identifiable {
    let id = UUID()
    let from: CGPoint
    let to: CGPoint
}
