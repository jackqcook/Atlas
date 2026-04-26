import SwiftUI
import PhotosUI

private let atlasPersonalCrimson = Color(red: 0.74, green: 0.05, blue: 0.16)

private enum NoteDestination: Hashable {
    case existing(ProfileNoteCard)
    case new(ProfileNoteCard)
}

struct PersonalView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var profile: UserProfileRecord?
    @State private var path = NavigationPath()
    @State private var showEditProfile = false
    @State private var showGrowthMap = false
    @State private var searchText = ""
    @State private var selectedCategory: PersonalNoteCategory?

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    if let profile {
                        VStack(alignment: .leading, spacing: 24) {
                            growthMapRow
                                .padding(.horizontal, 20)
                            recentsSection(profile: profile)
                            collectionsSection(profile: profile)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 18)
                        .padding(.bottom, 110)
                    }
                }
                .background(Color.white.ignoresSafeArea())

                composeButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
            }
            .navigationTitle("Personal")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditProfile = true
                    } label: {
                        if let user = authVM.currentUser, let profile {
                            avatarView(user: user, profile: profile, size: 34)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .task {
                await loadProfile()
            }
            .navigationDestination(for: NoteDestination.self) { destination in
                let isNew = { if case .new = destination { return true }; return false }()
                let note = { switch destination { case .existing(let n): return n; case .new(let n): return n } }()
                PersonalNoteEditor(
                    note: note,
                    allNotes: profile?.notes ?? [],
                    isNew: isNew
                ) { saved in
                    Task {
                        if isNew { await addNote(saved) } else { await saveNote(saved) }
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let user = authVM.currentUser, let profile {
                    EditPersonalProfileSheet(
                        profile: profile,
                        initialDisplayName: user.displayName
                    ) { updated in
                        Task { await saveProfile(updated) }
                    }
                }
            }
            .sheet(isPresented: $showGrowthMap) {
                if let profile {
                    PersonalGraphView(profile: profile)
                }
            }
        }
    }

    private var composeButton: some View {
        Button {
            let draft = ProfileNoteCard(
                id: UUID(),
                title: "",
                prompt: "Capture something worth revisiting.",
                body: "",
                updatedAt: Date(),
                category: selectedCategory ?? .ideas
            )
            path.append(NoteDestination.new(draft))
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(atlasPersonalCrimson)
                .clipShape(Circle())
                .shadow(color: atlasPersonalCrimson.opacity(0.35), radius: 16, y: 6)
        }
    }

    private var growthMapRow: some View {
        Button {
            showGrowthMap = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.13, green: 0.13, blue: 0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Growth Map")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("See how ideas, goals, and people connect")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(atlasPersonalCrimson)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(red: 0.985, green: 0.985, blue: 0.99))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func recentsSection(profile: UserProfileRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(selectedCategory == nil ? "Recents" : "\(selectedCategory?.displayName ?? "") Notes")
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            ForEach(Array(filteredNotes.prefix(8).enumerated()), id: \.element.id) { index, note in
                Button {
                    path.append(NoteDestination.existing(note))
                } label: {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(index == 0 ? Color(red: 0.95, green: 0.95, blue: 0.96) : Color.clear)
                }
                .buttonStyle(.plain)

                if index < filteredNotes.prefix(8).count - 1 {
                    Divider()
                        .padding(.leading, 20)
                }
            }
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
}

private struct EditPersonalProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authVM
    @State private var draft: UserProfileRecord
    @State private var goalsText: String
    @State private var displayName: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showSignOutAlert = false
    let onSave: (UserProfileRecord) -> Void

    init(profile: UserProfileRecord, initialDisplayName: String, onSave: @escaping (UserProfileRecord) -> Void) {
        _draft = State(initialValue: profile)
        _goalsText = State(initialValue: profile.goals.joined(separator: ", "))
        _displayName = State(initialValue: initialDisplayName)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    avatarPicker
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)

                    editField("Display Name", text: $displayName, prompt: "Your name")
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

                    Button {
                        showSignOutAlert = true
                    } label: {
                        Text("Sign Out")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(atlasPersonalCrimson)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(atlasPersonalCrimson.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.985).ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        draft.avatarImageData = data
                    }
                }
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    Task { await authVM.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need your phone number to sign back in outside demo mode.")
            }
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
                        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty, trimmed != authVM.currentUser?.displayName {
                            Task { await authVM.updateDisplayName(trimmed) }
                        }
                        dismiss()
                    }
                    .foregroundStyle(atlasPersonalCrimson)
                }
            }
        }
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                if let data = draft.avatarImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(atlasPersonalCrimson.opacity(0.12))
                        .frame(width: 88, height: 88)
                        .overlay {
                            Text(String(displayName.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(atlasPersonalCrimson)
                        }
                }

                Circle()
                    .fill(atlasPersonalCrimson)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
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
    @State private var hasSaved = false
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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(draft.updatedAt.formatted(date: .long, time: .shortened))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 6)

                    TextField("Title", text: $draft.title)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)

                    TextField("Optional note prompt", text: $draft.prompt)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $draft.body)
                        .font(.system(size: 22, weight: .regular, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 340)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Linked Notes")
                            .font(.system(size: 15, weight: .bold))
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
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            bottomAccessoryBar
        }
        .background(Color(red: 1.0, green: 0.998, blue: 0.992).ignoresSafeArea())
        .navigationTitle(isNew ? "New Note" : (draft.title.isEmpty ? "Note" : draft.title))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 18) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.black)
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    saveAndDismiss()
                }
                .foregroundStyle(atlasPersonalCrimson)
            }
        }
        .onDisappear {
            guard !hasSaved else { return }
            autoSave()
        }
    }

    private var bottomAccessoryBar: some View {
        HStack(spacing: 28) {
            Image(systemName: "checklist")
            Image(systemName: "paperclip")
            Image(systemName: "pencil.tip.crop.circle")
        }
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(.black)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color.white)
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 16, y: 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .padding(.top, 12)
    }

    private func saveAndDismiss() {
        hasSaved = true
        draft.updatedAt = Date()
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.title = "Untitled Note"
        }
        onSave(draft)
        dismiss()
    }

    private func autoSave() {
        let hasContent = !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                         !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasContent else { return }
        draft.updatedAt = Date()
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.title = "Untitled Note"
        }
        onSave(draft)
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
