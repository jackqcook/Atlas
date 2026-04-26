import SwiftUI
import PhotosUI

private let atlasPersonalCrimson = Color(red: 0.74, green: 0.05, blue: 0.16)

private enum NoteDestination: Hashable {
    case existing(ProfileNoteCard)
    case new(ProfileNoteCard)

    var note: ProfileNoteCard {
        switch self {
        case .existing(let note), .new(let note):
            return note
        }
    }

    var isNew: Bool {
        if case .new = self { return true }
        return false
    }
}

extension NoteDestination: Identifiable {
    var id: UUID { note.id }
}

struct PersonalView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var profile: UserProfileRecord?
    @State private var showEditProfile = false
    @State private var showMindMap = false
    @State private var showThoughts = false
    @State private var searchText = ""
    @State private var selectedCategory: PersonalNoteCategory?
    @State private var activeNoteID: UUID?
    @State private var draft = Self.blankNote()
    @State private var isSidebarOpen = false
    @State private var showFeedbackPanel = false
    @State private var autosaveTask: Task<Void, Never>?
    @State private var editorDestination: NoteDestination?
    @FocusState private var isEditorFocused: Bool
    @State private var isSearchActive = false
    @State private var noteToShare: ProfileNoteCard?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            notesHome
            .background(Color(red: 1.0, green: 0.998, blue: 0.992).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await loadProfile()
            }
            .fullScreenCover(isPresented: $showEditProfile) {
                if let user = authVM.currentUser, let profile {
                    EditPersonalProfileSheet(
                        profile: profile,
                        initialDisplayName: user.displayName
                    ) { updated in
                        Task { await saveProfile(updated) }
                    }
                }
            }
            .fullScreenCover(isPresented: $showMindMap) {
                if let profile {
                    PersonalMindMapView(profile: profile)
                }
            }
            .sheet(isPresented: $showThoughts) {
                ThoughtsSheet(readyFeedbackCount: readyFeedbackCount)
            }
            .fullScreenCover(item: $editorDestination) { destination in
                NavigationStack {
                    PersonalNoteEditor(
                        note: destination.note,
                        allNotes: profile?.notes ?? [],
                        isNew: destination.isNew
                    ) { saved in
                        Task {
                            if destination.isNew {
                                await addNote(saved)
                            } else {
                                await saveNote(saved)
                            }
                        }
                    }
                }
            }
            .sheet(item: $noteToShare) { note in
                ShareSheet(items: [
                    [note.title, note.body]
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .joined(separator: "\n\n")
                ])
            }
        }
    }

    private var notesHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                homeHeader
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 24) {
                    if !isSearchActive {
                        homeActions
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(isSearchActive ? "Previous Chats" : "Recents")
                            .font(.custom("Helvetica-Bold", size: 18))
                            .foregroundStyle(.black)

                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredNotes) { note in
                                NoteSwipeRow(
                                    note: note,
                                    title: displayTitle(for: note),
                                    isActive: note.id == activeNoteID,
                                    onTap: { select(note) },
                                    onShare: { noteToShare = note },
                                    onMove: { },
                                    onDelete: { delete(note) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 0)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private var homeHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                if !isSearchActive {
                    Text(authVM.currentUser?.displayName ?? "Notes")
                        .font(.custom("Helvetica-Bold", size: 34))
                        .foregroundStyle(.black)
                        .frame(height: 60, alignment: .center)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        let opening = !isSearchActive
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSearchActive = opening
                            if !opening { searchText = "" }
                        }
                        if opening {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                isSearchFocused = true
                            }
                        }
                    } label: {
                        Image(systemName: isSearchActive ? "xmark" : "magnifyingglass")
                            .font(.system(size: isSearchActive ? 15 : 20, weight: isSearchActive ? .bold : .regular))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showEditProfile = true
                    } label: {
                        if let user = authVM.currentUser, let profile {
                            avatarView(user: user, profile: profile, size: 42)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .frame(height: 60)
                .background(Color.white.opacity(0.92))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
            }

            if isSearchActive {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    TextField("Search notes", text: $searchText)
                        .font(.custom("Helvetica", size: 15))
                        .focused($isSearchFocused)
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 15)
                .frame(height: 46)
                .background(Color.black.opacity(0.045))
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var homeActions: some View {
        VStack(alignment: .leading, spacing: 20) {
            homeAction(title: "New Note", icon: "square.and.pencil") {
                startNewNote()
            }
            homeAction(title: "Mind Map", icon: "network") {
                showMindMap = true
            }
            homeAction(title: "Thoughts", icon: "bubble.left.and.text.bubble.right") {
                showThoughts = true
            }
        }
        .padding(.top, 8)
        .transition(.opacity)
    }

    private var searchField: some View {
        TextField("Search notes", text: $searchText)
            .font(.custom("Helvetica", size: 15))
            .padding(.horizontal, 15)
            .frame(height: 46)
            .background(Color.black.opacity(0.045))
            .clipShape(Capsule())
    }

    private func homeAction(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.custom("Helvetica-Bold", size: 20))
                            .foregroundStyle(.black)

                        if title == "Thoughts", readyFeedbackCount > 0 {
                            Text("\(readyFeedbackCount) ready")
                                .font(.custom("Helvetica-Bold", size: 11))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(atlasPersonalCrimson)
                                .clipShape(Capsule())
                        }
                    }

                    Text(actionSubtitle(for: title))
                        .font(.custom("Helvetica", size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.black)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func actionSubtitle(for title: String) -> String {
        switch title {
        case "New Note":
            return "Start writing"
        case "Mind Map":
            return "See connections"
        case "Thoughts":
            return "Patterns and signals"
        default:
            return ""
        }
    }

    private func homeNoteRow(_ note: ProfileNoteCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayTitle(for: note))
                .font(.custom("Helvetica-Bold", size: 18))
                .foregroundStyle(note.id == activeNoteID ? atlasPersonalCrimson : .black)
                .lineLimit(1)

            if !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note.body)
                    .font(.custom("Helvetica", size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.custom("Helvetica", size: 11))
                .foregroundStyle(.secondary.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private var noteCanvas: some View {
        VStack(alignment: .leading, spacing: 0) {
            topControls

            HStack(spacing: 10) {
                feedbackButton

                Spacer()

                Text(autosaveLabel)
                    .font(.custom("Helvetica", size: 14))
                    .foregroundStyle(.black.opacity(0.42))
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)

            TextField("Untitled", text: $draft.title)
                .font(.custom("Helvetica-Bold", size: 42))
                .foregroundStyle(.black)
                .padding(.horizontal, 22)
                .padding(.top, 28)

            TextEditor(text: $draft.body)
                .font(.custom("Helvetica", size: 24))
                .foregroundStyle(.black.opacity(0.88))
                .lineSpacing(7)
                .scrollContentBackground(.hidden)
                .focused($isEditorFocused)
                .padding(.horizontal, 17)
                .padding(.top, 6)
                .overlay(alignment: .topLeading) {
                    if draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Scribble what you are scheming...")
                            .font(.custom("Helvetica", size: 24))
                            .foregroundStyle(.black.opacity(0.24))
                            .padding(.leading, 22)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }

            noteBottomBar
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 6)
        }
    }

    private var topControls: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    isSidebarOpen.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.07), radius: 18, y: 8)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showEditProfile = true
            } label: {
                if let user = authVM.currentUser, let profile {
                    avatarView(user: user, profile: profile, size: 54)
                        .padding(5)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.07), radius: 18, y: 8)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var feedbackButton: some View {
        Button {
            showFeedbackPanel.toggle()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(feedbackColor)
                    .frame(width: 8, height: 8)
                Text(feedbackLabel)
                    .font(.custom("Helvetica-Bold", size: 12))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.82))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.04), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showFeedbackPanel) {
            feedbackPanel
                .presentationCompactAdaptation(.popover)
        }
    }

    private var feedbackPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LLM Feedback")
                .font(.custom("Helvetica-Bold", size: 18))
            Text(feedbackExplanation)
                .font(.custom("Helvetica", size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
            if !draft.llmFeedback.isEmpty {
                Divider()
                Text(draft.llmFeedback)
                    .font(.custom("Helvetica", size: 15))
                    .foregroundStyle(.black)
                    .lineSpacing(4)
            }
            Button {
                markFeedbackRequested()
            } label: {
                Text("Request feedback")
                    .font(.custom("Helvetica-Bold", size: 14))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(atlasPersonalCrimson)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(width: 300)
    }

    private var noteBottomBar: some View {
        HStack(spacing: 14) {
            categoryMenu

            Button {
                showMindMap = true
            } label: {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.86))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            if noteHasContent(draft) {
                Button(role: .destructive) {
                    deleteCurrentNote()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(atlasPersonalCrimson)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.86))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Button {
                isEditorFocused = false
                persistDraftIfNeeded()
            } label: {
                Text("Save")
                    .font(.custom("Helvetica-Bold", size: 14))
                    .foregroundStyle(atlasPersonalCrimson)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(Color.white.opacity(0.86))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!hasWriting(draft))
            .opacity(hasWriting(draft) ? 1 : 0.45)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(PersonalNoteCategory.allCases, id: \.self) { category in
                Button(category.displayName) {
                    draft.category = category
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: categoryIcon(for: draft.category))
                    .font(.system(size: 15, weight: .semibold))
                Text(draft.category.displayName)
                    .font(.custom("Helvetica-Bold", size: 14))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 15)
            .frame(height: 42)
            .background(Color.white.opacity(0.86))
            .clipShape(Capsule())
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Notes")
                    .font(.custom("Helvetica-Bold", size: 30))
                    .foregroundStyle(.black)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        isSidebarOpen = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black.opacity(0.62))
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 22)

            sidebarAction(title: "Blank note", icon: "square.and.pencil") {
                startNewNote()
                isSidebarOpen = false
            }
            sidebarAction(title: "Mind Map", icon: "point.3.connected.trianglepath.dotted") {
                showMindMap = true
                isSidebarOpen = false
            }

            TextField("Search notes", text: $searchText)
                .font(.custom("Helvetica", size: 15))
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color.black.opacity(0.045))
                .clipShape(Capsule())
                .padding(.horizontal, 22)
                .padding(.top, 18)

            HStack {
                Text("Recents")
                    .font(.custom("Helvetica-Bold", size: 18))
                    .foregroundStyle(.secondary)
                Spacer()
                if readyFeedbackCount > 0 {
                    Text("\(readyFeedbackCount) ready")
                        .font(.custom("Helvetica-Bold", size: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(atlasPersonalCrimson)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredNotes) { note in
                        Button {
                            select(note)
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                isSidebarOpen = false
                            }
                        } label: {
                            sidebarNoteRow(note)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(note)
                            } label: {
                                Label("Delete note", systemImage: "trash")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 28)
            }
        }
        .containerRelativeFrame(.horizontal) { length, _ in
            min(length * 0.82, 360)
        }
        .frame(maxHeight: .infinity)
        .background(Color(red: 0.98, green: 0.975, blue: 0.955))
        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 34, topTrailingRadius: 34))
        .shadow(color: .black.opacity(0.16), radius: 24, x: 8, y: 8)
        .ignoresSafeArea(edges: .vertical)
    }

    private func sidebarAction(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 26)
                Text(title)
                    .font(.custom("Helvetica-Bold", size: 22))
                Spacer()
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private func sidebarNoteRow(_ note: ProfileNoteCard) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(displayTitle(for: note))
                    .font(.custom("Helvetica-Bold", size: 18))
                    .foregroundStyle(note.id == activeNoteID ? atlasPersonalCrimson : .black)
                    .lineLimit(1)
                Spacer()
                feedbackIndicator(for: note)
            }
            if !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note.body)
                    .font(.custom("Helvetica", size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.custom("Helvetica", size: 11))
                .foregroundStyle(.secondary.opacity(0.85))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 13)
        .background(note.id == activeNoteID ? Color.white.opacity(0.76) : Color.clear)
    }

    @ViewBuilder
    private func feedbackIndicator(for note: ProfileNoteCard) -> some View {
        switch note.llmFeedbackStatus {
        case .responded:
            Circle()
                .fill(atlasPersonalCrimson)
                .frame(width: 9, height: 9)
        case .waiting:
            Circle()
                .stroke(atlasPersonalCrimson, lineWidth: 2)
                .frame(width: 10, height: 10)
        case .none:
            EmptyView()
        }
    }

    private var feedbackColor: Color {
        switch draft.llmFeedbackStatus {
        case .none: return .secondary.opacity(0.45)
        case .waiting: return Color.orange
        case .responded: return atlasPersonalCrimson
        }
    }

    private var feedbackLabel: String {
        switch draft.llmFeedbackStatus {
        case .none: return "No feedback"
        case .waiting: return "Thinking"
        case .responded: return "Feedback ready"
        }
    }

    private var feedbackExplanation: String {
        switch draft.llmFeedbackStatus {
        case .none:
            return "When this note is sent to an LLM, mark it as waiting. When a response is saved back, it becomes feedback ready and gets a red dot in the sidebar."
        case .waiting:
            return "This note has been queued for LLM feedback. Keep writing; the note will show as ready when the feedback payload is saved."
        case .responded:
            return draft.llmFeedbackUpdatedAt.map { "Feedback received \($0.formatted(date: .abbreviated, time: .shortened))." } ?? "Feedback has been received for this note."
        }
    }

    private var autosaveLabel: String {
        guard noteHasContent(draft) else { return "Blank note" }
        return "Saved \(draft.updatedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var readyFeedbackCount: Int {
        profile?.notes.filter { $0.llmFeedbackStatus == .responded }.count ?? 0
    }

    private var filteredNotes: [ProfileNoteCard] {
        let base = profile?.notes
            .filter(noteHasContent)
            .sorted(by: { $0.updatedAt > $1.updatedAt }) ?? []

        return base.filter { note in
            let categoryMatches = selectedCategory == nil || note.category == selectedCategory
            let searchMatches =
                searchText.isEmpty ||
                displayTitle(for: note).localizedCaseInsensitiveContains(searchText) ||
                note.body.localizedCaseInsensitiveContains(searchText) ||
                note.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            return categoryMatches && searchMatches
        }
    }

    private func select(_ note: ProfileNoteCard) {
        activeNoteID = note.id
        editorDestination = .existing(note)
    }

    private func startNewNote() {
        let note = Self.blankNote(category: selectedCategory ?? .ideas)
        activeNoteID = note.id
        searchText = ""
        editorDestination = .new(note)
    }

    private func markFeedbackRequested() {
        guard hasWriting(draft) else { return }
        draft.llmFeedbackStatus = .waiting
        draft.llmFeedback = ""
        draft.llmFeedbackUpdatedAt = nil
        persistDraftIfNeeded(force: true)
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            persistDraftIfNeeded()
        }
    }

    private func persistDraftIfNeeded(force: Bool = false) {
        guard var profile else { return }
        guard force || hasWriting(draft) else { return }

        draft.updatedAt = Date()
        applyAutomaticTags(to: &draft)

        if let index = profile.notes.firstIndex(where: { $0.id == draft.id }) {
            profile.notes[index] = draft
        } else {
            profile.notes.insert(draft, at: 0)
        }

        normalizeTags(&profile)
        ProfileStore.shared.saveProfile(profile)
        self.profile = profile
        activeNoteID = draft.id
    }

    private func noteHasContent(_ note: ProfileNoteCard) -> Bool {
        !note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !note.llmFeedback.isEmpty ||
        note.llmFeedbackStatus != .none
    }

    private func hasWriting(_ note: ProfileNoteCard) -> Bool {
        !note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func deleteCurrentNote() {
        delete(draft)
    }

    private func delete(_ note: ProfileNoteCard) {
        guard var profile else { return }
        profile.notes.removeAll { $0.id == note.id }
        ProfileStore.shared.saveProfile(profile)
        self.profile = profile

        if activeNoteID == note.id || draft.id == note.id {
            activeNoteID = nil
            draft = Self.blankNote(category: selectedCategory ?? .ideas)
            showFeedbackPanel = false
        }
    }

    private func displayTitle(for note: ProfileNoteCard) -> String {
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }

        let firstLine = note.body
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return firstLine.isEmpty ? "Untitled Note" : firstLine
    }

    private static func blankNote(category: PersonalNoteCategory = .ideas) -> ProfileNoteCard {
        ProfileNoteCard(
            id: UUID(),
            title: "",
            prompt: "Capture something worth revisiting.",
            body: "",
            updatedAt: Date(),
            category: category
        )
    }

    private func applyAutomaticTags(to note: inout ProfileNoteCard) {
        let categoryTag = note.category.displayName.lowercased()
        var tags = note.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if !tags.contains(categoryTag) {
            tags.insert(categoryTag, at: 0)
        }
        note.tags = Array(NSOrderedSet(array: tags)) as? [String] ?? tags
    }

    private func notes(for category: PersonalNoteCategory, in profile: UserProfileRecord) -> [ProfileNoteCard] {
        profile.notes.filter { $0.category == category }
    }

    private func categoryIcon(for category: PersonalNoteCategory) -> String {
        switch category {
        case .goals: return "target"
        case .projects: return "folder"
        case .connections: return "person.2"
        case .ideas: return "sparkles"
        case .reflections: return "quote.bubble"
        }
    }

    private func loadProfile() async {
        guard let user = authVM.currentUser else { return }
        let loaded = ProfileStore.shared.loadProfile(for: user)
        profile = loaded
        activeNoteID = nil
        draft = Self.blankNote()
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
        normalizeTags(&profile)
        await saveProfile(profile)
    }

    private func addNote(_ note: ProfileNoteCard) async {
        guard var profile else { return }
        profile.notes.insert(note, at: 0)
        normalizeTags(&profile)
        await saveProfile(profile)
    }

    private func normalizeTags(_ profile: inout UserProfileRecord) {
        profile.notes = profile.notes.map { note in
            var updated = note
            applyAutomaticTags(to: &updated)
            return updated
        }
    }

    private func collectionsSection(profile: UserProfileRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Browse")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    filterChip(
                        title: "All",
                        count: profile.notes.count,
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(PersonalNoteCategory.allCases, id: \.self) { category in
                        filterChip(
                            title: category.displayName,
                            count: notes(for: category, in: profile).count,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.custom("Helvetica-Bold", size: 18))
            .foregroundStyle(.black)
    }

    private func filterChip(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.custom("Helvetica-Bold", size: 13))
                Text("\(count)")
                    .font(.custom("Helvetica", size: 12))
                    .opacity(0.85)
            }
            .foregroundStyle(isSelected ? .white : .black)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? atlasPersonalCrimson : Color(red: 0.95, green: 0.95, blue: 0.96))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
                    profileHero
                    aboutCard
                    linksCard
                    accountCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
            .background(Color(red: 1.0, green: 0.998, blue: 0.992).ignoresSafeArea())
            .navigationTitle("")
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
                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                            .labelStyle(.titleAndIcon)
                            .font(.custom("Helvetica-Bold", size: 15))
                    }
                    .foregroundStyle(.black.opacity(0.72))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveAndDismiss()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .labelStyle(.titleAndIcon)
                            .font(.custom("Helvetica-Bold", size: 15))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .foregroundStyle(atlasPersonalCrimson)
                }
            }
        }
    }

    private var profileHero: some View {
        VStack(alignment: .center, spacing: 14) {
            avatarPicker
            Text("Profile")
                .font(.custom("Helvetica-Bold", size: 34))
                .foregroundStyle(.black)
            TextField("Display name", text: $displayName)
                .font(.custom("Helvetica", size: 17))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.black.opacity(0.045))
                .clipShape(Capsule())
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.custom("Helvetica-Bold", size: 20))
                .foregroundStyle(.black)
            TextEditor(text: $draft.about)
                .font(.custom("Helvetica", size: 16))
                .lineSpacing(4)
                .frame(minHeight: 190)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(18)
        .background(Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var linksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Links")
                .font(.custom("Helvetica-Bold", size: 20))
                .foregroundStyle(.black)
            editField("Website", text: $draft.website, prompt: "quentinjcook.com")
            editField("Community page", text: $draft.communityLabel, prompt: "BYU - sb05")

            HStack(spacing: 10) {
                linkPill("Notes")
                linkPill("Mind Map")
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func linkPill(_ title: String) -> some View {
        Text(title)
            .font(.custom("Helvetica-Bold", size: 13))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.045))
            .clipShape(Capsule())
    }

    private var accountCard: some View {
        Button {
            showSignOutAlert = true
        } label: {
            Text("Sign Out")
                .font(.custom("Helvetica-Bold", size: 16))
                .foregroundStyle(atlasPersonalCrimson)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
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
                                .font(.custom("Helvetica-Bold", size: 28))
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
                .font(.custom("Helvetica-Bold", size: 12))
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .font(.custom("Helvetica", size: 15))
                .padding(14)
                .background(Color.black.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func saveAndDismiss() {
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
}

private struct PersonalNoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProfileNoteCard
    @State private var hasSaved = false
    @State private var bodyHeight: CGFloat = 600
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
        ZStack(alignment: .bottom) {
            Color(red: 1.0, green: 0.998, blue: 0.992)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("", text: $draft.title, prompt: Text("Untitled").foregroundStyle(.black.opacity(0.22)))
                        .font(.custom("Helvetica-Bold", size: 20))
                        .foregroundStyle(.black.opacity(0.76))
                        .padding(.top, 80)
                        .padding(.horizontal, 28)

                    ZStack(alignment: .topLeading) {
                        AutoSizingTextView(text: $draft.body, dynamicHeight: $bodyHeight)
                            .frame(height: max(500, bodyHeight))
                            .padding(.horizontal, 23)
                            .padding(.top, 2)

                        if draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Scribble what you are scheming...")
                                .font(.custom("Helvetica", size: 22))
                                .foregroundStyle(.black.opacity(0.20))
                                .padding(.top, 10)
                                .padding(.leading, 28)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .topLeading) {
                Button {
                    saveAndDismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.82))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.leading, 22)
                .padding(.top, 18)
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 18) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .regular))
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(.black.opacity(0.84))
                .frame(width: 96, height: 44)
                .background(Color.white.opacity(0.9))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
                .padding(.trailing, 22)
                .padding(.top, 18)
            }

            bottomAccessoryBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            guard !hasSaved else { return }
            autoSave()
        }
    }

    private var bottomAccessoryBar: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 34) {
                Image(systemName: "checklist")
                Image(systemName: "paperclip")
                Image(systemName: "pencil.tip.crop.circle")
            }
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(.black)
            .padding(.horizontal, 22)
            .frame(height: 48)
            .background(Color.white.opacity(0.92))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 18, y: 8)

            Spacer()

            Button {
                saveAndDismiss()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.black)
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 28)
    }

    private func saveAndDismiss() {
        hasSaved = true
        let hasContent = !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                         !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasContent else {
            dismiss()
            return
        }
        draft.updatedAt = Date()
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.title = "Untitled Note"
        }
        applyAutomaticTags()
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
        applyAutomaticTags()
        onSave(draft)
    }

    private func toggleLink(_ id: UUID) {
        if draft.linkedNoteIDs.contains(id) {
            draft.linkedNoteIDs.removeAll { $0 == id }
        } else {
            draft.linkedNoteIDs.append(id)
        }
    }

    private func applyAutomaticTags() {
        let categoryTag = draft.category.displayName.lowercased()
        var tags = draft.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if !tags.contains(categoryTag) {
            tags.insert(categoryTag, at: 0)
        }
        draft.tags = Array(NSOrderedSet(array: tags)) as? [String] ?? tags
    }
}

private struct PersonalMindMapView: View {
    let profile: UserProfileRecord
    @Environment(\.dismiss) private var dismiss
    @State private var selectedNoteID: UUID?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.085, blue: 0.075),
                        Color(red: 0.18, green: 0.12, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                PersonalGraphCanvas(
                    notes: meaningfulNotes,
                    selectedNoteID: $selectedNoteID,
                    searchText: searchText
                )
                    .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mind Map")
                                .font(.custom("Helvetica-Bold", size: 22))
                            Text("Search to focus a note. Drag to move. Pinch to zoom.")
                                .font(.custom("Helvetica", size: 12))
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        .foregroundStyle(.white)

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.54))
                        TextField("Search notes", text: $searchText)
                            .font(.custom("Helvetica", size: 15))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.never)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                selectedNoteID = meaningfulNotes.first?.id
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.46))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.44), .black.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .onAppear {
                selectedNoteID = meaningfulNotes.first?.id
            }
            .onChange(of: searchText) { _, newValue in
                guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    selectedNoteID = meaningfulNotes.first?.id
                    return
                }
                selectedNoteID = bestSearchMatch(for: newValue)?.id
            }
        }
    }

    private var meaningfulNotes: [ProfileNoteCard] {
        profile.notes.filter {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var selectedNote: ProfileNoteCard? {
        meaningfulNotes.first(where: { $0.id == selectedNoteID }) ?? meaningfulNotes.first
    }

    private func bestSearchMatch(for query: String) -> ProfileNoteCard? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return meaningfulNotes.first }

        return meaningfulNotes.first {
            displayTitle(for: $0).localizedCaseInsensitiveContains(trimmed) ||
            $0.body.localizedCaseInsensitiveContains(trimmed) ||
            $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) })
        }
    }

    private func selectedNoteCard(_ note: ProfileNoteCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(displayTitle(for: note))
                    .font(.custom("Helvetica-Bold", size: 22))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Spacer()
            }

            Text(note.body.isEmpty ? "No body text yet." : note.body)
                .font(.custom("Helvetica", size: 15))
                .foregroundStyle(.black.opacity(0.72))
                .lineSpacing(4)
                .lineLimit(4)

            if !note.linkedNoteIDs.isEmpty {
                Text("\(note.linkedNoteIDs.count) linked idea\(note.linkedNoteIDs.count == 1 ? "" : "s")")
                    .font(.custom("Helvetica-Bold", size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }

    private func displayTitle(for note: ProfileNoteCard) -> String {
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let firstLine = note.body
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.isEmpty ? "Untitled Note" : firstLine
    }
}

private struct ThoughtsSheet: View {
    let readyFeedbackCount: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Thoughts")
                        .font(.custom("Helvetica-Bold", size: 30))
                        .foregroundStyle(.black)

                    Text("This is where Atlas can gradually surface patterns, contradictions, recurring themes, and useful next steps from your notes.")
                        .font(.custom("Helvetica", size: 16))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Status")
                            .font(.custom("Helvetica-Bold", size: 18))
                            .foregroundStyle(.black)
                        Text(readyFeedbackCount == 0 ? "No note feedback is ready yet." : "\(readyFeedbackCount) note\(readyFeedbackCount == 1 ? "" : "s") have feedback ready.")
                            .font(.custom("Helvetica", size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Coming next")
                            .font(.custom("Helvetica-Bold", size: 18))
                            .foregroundStyle(.black)
                        Text("As this develops, this space can become the place where Atlas helps you notice what you keep returning to and how your thinking is changing.")
                            .font(.custom("Helvetica", size: 15))
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
                }
                .padding(20)
            }
            .background(Color(red: 1.0, green: 0.998, blue: 0.992).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(atlasPersonalCrimson)
                }
            }
        }
    }
}

private struct PersonalGraphCanvas: View {
    let notes: [ProfileNoteCard]
    @Binding var selectedNoteID: UUID?
    let searchText: String

    var body: some View {
        PersonalGraphDrawing(
            notes: notes,
            selectedNoteID: $selectedNoteID,
            searchText: searchText,
            allowsTap: true
        )
    }
}

private struct PersonalGraphDrawing: View {
    let notes: [ProfileNoteCard]
    @Binding var selectedNoteID: UUID?
    let searchText: String
    let allowsTap: Bool
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let nodes = layoutNodes(in: geometry.size)
            let focusedIDs = focusedNoteIDs()

            ZStack {
                starField(in: geometry.size)

                ZStack {
                    ForEach(edgePairs(from: nodes), id: \.id) { edge in
                        let isFocusedEdge = selectedNoteID == nil || edge.fromID == selectedNoteID || edge.toID == selectedNoteID
                        Path { path in
                            path.move(to: edge.from)
                            path.addQuadCurve(
                                to: edge.to,
                                control: CGPoint(
                                    x: (edge.from.x + edge.to.x) / 2,
                                    y: min(edge.from.y, edge.to.y) - 80
                                )
                            )
                        }
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(isFocusedEdge ? 0.18 : 0.035),
                                    atlasPersonalCrimson.opacity(isFocusedEdge ? 0.72 : 0.14),
                                    .white.opacity(isFocusedEdge ? 0.16 : 0.035)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: isFocusedEdge ? 3 : 1.4, lineCap: .round)
                        )
                        .shadow(color: atlasPersonalCrimson.opacity(isFocusedEdge ? 0.42 : 0.06), radius: isFocusedEdge ? 9 : 2)
                    }

                    ForEach(nodes) { node in
                        let depth = nodeDepth(node.note)
                        let isFocused = focusedIDs == nil || focusedIDs?.contains(node.note.id) == true
                        let isPrimary = node.note.id == selectedNoteID
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(nodeColor(node.note).opacity(0.25))
                                        .frame(width: 34, height: 34)
                                        .blur(radius: 8)

                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    .white.opacity(isPrimary ? 0.98 : 0.70),
                                                    nodeColor(node.note),
                                                    nodeColor(node.note).opacity(0.48)
                                                ],
                                                center: .topLeading,
                                                startRadius: 1,
                                                endRadius: 24
                                            )
                                        )
                                        .frame(width: isPrimary ? 24 : 18, height: isPrimary ? 24 : 18)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(isPrimary ? 0.85 : 0.22), lineWidth: 2)
                                        )
                                        .shadow(color: nodeColor(node.note).opacity(0.55), radius: 16 * depth, x: 0, y: 10 * depth)
                                }

                                Text(displayTitle(for: node.note))
                                    .font(.custom("Helvetica-Bold", size: isPrimary ? 13 : 11))
                                    .foregroundStyle(.white.opacity(isFocused ? 0.96 : 0.36))
                                    .lineLimit(1)
                            }

                            Text(node.note.body.isEmpty ? "No body text yet." : node.note.body)
                                .font(.custom("Helvetica", size: 9))
                                .foregroundStyle(.white.opacity(isFocused ? 0.54 : 0.22))
                                .lineLimit(2)
                        }
                        .frame(width: isPrimary ? 150 : 132, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .scaleEffect(depth * (isPrimary ? 1.08 : 1.0))
                        .rotation3DEffect(.degrees(Double((node.position.x - geometry.size.width / 2) / geometry.size.width) * 16), axis: (x: 0, y: 1, z: 0))
                        .rotation3DEffect(.degrees(Double((node.position.y - geometry.size.height / 2) / geometry.size.height) * -10), axis: (x: 1, y: 0, z: 0))
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isPrimary ? 0.22 : (isFocused ? 0.13 : 0.045)),
                                    Color.white.opacity(isPrimary ? 0.11 : (isFocused ? 0.06 : 0.025))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(isPrimary ? 0.34 : (isFocused ? 0.13 : 0.04)), lineWidth: 1)
                        )
                        .opacity(isFocused ? 1 : 0.45)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 18 * depth, x: 0, y: 14 * depth)
                            .position(node.position)
                            .onTapGesture {
                                guard allowsTap else { return }
                                selectedNoteID = node.note.id
                            }
                    }
                }
                .scaleEffect(zoom)
                .offset(panOffset)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        panOffset = CGSize(
                            width: lastPanOffset.width + value.translation.width,
                            height: lastPanOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastPanOffset = panOffset
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        zoom = min(max(lastZoom * value.magnification, 0.65), 2.2)
                    }
                    .onEnded { _ in
                        lastZoom = zoom
                    }
            )
        }
    }

    @ViewBuilder
    private func starField(in size: CGSize) -> some View {
        ForEach(0..<34, id: \.self) { index in
            Circle()
                .fill(Color.white.opacity(index.isMultiple(of: 3) ? 0.18 : 0.08))
                .frame(width: CGFloat(2 + (index % 3)), height: CGFloat(2 + (index % 3)))
                .position(
                    x: CGFloat((index * 71) % 397) / 397 * size.width,
                    y: CGFloat((index * 113) % 719) / 719 * size.height
                )
        }
    }

    private func layoutNodes(in size: CGSize) -> [PersonalGraphNode] {
        var result: [PersonalGraphNode] = []
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
        let goldenAngle = Double.pi * (3 - sqrt(5))

        for (index, note) in notes.enumerated() {
            let angle = Double(index) * goldenAngle
            let radius = CGFloat(index == 0 ? 0 : 58 + sqrt(Double(index)) * 58)
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius * 0.72
            result.append(PersonalGraphNode(note: note, position: CGPoint(x: x, y: y)))
        }

        return result
    }

    private func focusedNoteIDs() -> Set<UUID>? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let selectedNoteID else { return nil }

        var ids: Set<UUID> = [selectedNoteID]
        if let selected = notes.first(where: { $0.id == selectedNoteID }) {
            ids.formUnion(selected.linkedNoteIDs)
        }

        for note in notes where note.linkedNoteIDs.contains(selectedNoteID) {
            ids.insert(note.id)
        }

        return ids
    }

    private func edgePairs(from nodes: [PersonalGraphNode]) -> [PersonalEdge] {
        let positions = Dictionary(uniqueKeysWithValues: nodes.map { ($0.note.id, $0.position) })
        var edges: [PersonalEdge] = []

        for node in nodes {
            for linkedID in node.note.linkedNoteIDs {
                guard let linkedPosition = positions[linkedID], node.note.id.uuidString < linkedID.uuidString else { continue }
                edges.append(PersonalEdge(from: node.position, to: linkedPosition, fromID: node.note.id, toID: linkedID))
            }
        }

        return edges
    }

    private func nodeColor(_ note: ProfileNoteCard) -> Color {
        if note.id == selectedNoteID {
            return .white
        }

        return categoryColor(note.category)
    }

    private func categoryColor(_ category: PersonalNoteCategory) -> Color {
        switch category {
        case .goals, .reflections:
            return Color(red: 0.16, green: 0.80, blue: 0.43)
        case .projects:
            return Color(red: 0.95, green: 0.78, blue: 0.28)
        case .connections:
            return Color(red: 0.42, green: 0.72, blue: 0.95)
        case .ideas:
            return atlasPersonalCrimson.opacity(0.92)
        }
    }

    private func nodeDiameter(_ note: ProfileNoteCard) -> CGFloat {
        let linkBoost = CGFloat(note.linkedNoteIDs.count) * 2
        return note.id == selectedNoteID ? 30 : max(18, 20 + linkBoost)
    }

    private func nodeDepth(_ note: ProfileNoteCard) -> CGFloat {
        let seed = abs(note.id.uuidString.hashValue % 7)
        return 0.78 + CGFloat(seed) * 0.055
    }

    private func displayTitle(for note: ProfileNoteCard) -> String {
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let firstLine = note.body
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.isEmpty ? "Untitled" : firstLine
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
    let fromID: UUID
    let toID: UUID
}

private struct NoteSwipeRow: View {
    let note: ProfileNoteCard
    let title: String
    let isActive: Bool
    let onTap: () -> Void
    let onShare: () -> Void
    let onMove: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var startOffset: CGFloat = 0
    @State private var startTranslation: CGFloat = 0
    @State private var swiping = false

    private static let buttonSize: CGFloat = 52
    private static let revealWidth: CGFloat = 200

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 12) {
                actionCircle(icon: "square.and.arrow.up", label: "Share", color: .blue) {
                    close(); onShare()
                }
                actionCircle(icon: "folder", label: "Move", color: Color(red: 0.40, green: 0.32, blue: 0.85)) {
                    close(); onMove()
                }
                actionCircle(icon: "trash", label: "Delete", color: Color(red: 0.82, green: 0.15, blue: 0.22)) {
                    close(); onDelete()
                }
            }
            .padding(.horizontal, 10)
            .opacity(offset < -16 ? 1 : 0)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.custom("Helvetica-Bold", size: 18))
                    .foregroundStyle(isActive ? Color(red: 0.74, green: 0.05, blue: 0.16) : .black)
                    .lineLimit(1)

                if !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(note.body)
                        .font(.custom("Helvetica", size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.custom("Helvetica", size: 11))
                    .foregroundStyle(.secondary.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(Color(red: 1.0, green: 0.998, blue: 0.992))
            .offset(x: offset)
            .onTapGesture {
                if offset != 0 { close() } else { onTap() }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let dx = abs(value.translation.width)
                        let dy = abs(value.translation.height)
                        guard dx > dy else { return }
                        if !swiping {
                            swiping = true
                            startOffset = offset
                            startTranslation = value.translation.width
                        }
                        offset = max(min(startOffset + value.translation.width - startTranslation, 0), -Self.revealWidth)
                    }
                    .onEnded { _ in
                        swiping = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            offset = offset < -Self.revealWidth / 2 ? -Self.revealWidth : 0
                        }
                    }
            )
        }
        .clipped()
    }

    private func close() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = 0
        }
    }

    private func actionCircle(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: Self.buttonSize, height: Self.buttonSize)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(.white)
                    }
                Text(label)
                    .font(.custom("Helvetica", size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AutoSizingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, dynamicHeight: $dynamicHeight)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textColor = UIColor.black.withAlphaComponent(0.72)
        textView.font = UIFont(name: "Helvetica", size: 22) ?? .systemFont(ofSize: 22)
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = UIFont(name: "Helvetica", size: 22) ?? .systemFont(ofSize: 22)
        context.coordinator.recalculateHeight(for: uiView)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var dynamicHeight: CGFloat

        init(text: Binding<String>, dynamicHeight: Binding<CGFloat>) {
            _text = text
            _dynamicHeight = dynamicHeight
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            recalculateHeight(for: textView)
        }

        func recalculateHeight(for textView: UITextView) {
            let fittingSize = CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)
            let nextHeight = max(500, textView.sizeThatFits(fittingSize).height)
            guard abs(dynamicHeight - nextHeight) > 1 else { return }
            DispatchQueue.main.async {
                self.dynamicHeight = nextHeight
            }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
