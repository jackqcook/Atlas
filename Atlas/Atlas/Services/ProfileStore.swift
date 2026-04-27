import Foundation

enum PersonalNoteCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case goals
    case projects
    case connections
    case ideas
    case reflections

    var displayName: String {
        switch self {
        case .goals: return "Goals"
        case .projects: return "Projects"
        case .connections: return "Connections"
        case .ideas: return "Ideas"
        case .reflections: return "Reflections"
        }
    }
}

enum LLMFeedbackStatus: String, Codable, Sendable, Hashable {
    case none
    case waiting
    case responded
}

struct ProfileNoteCard: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var title: String
    var prompt: String
    var body: String
    var updatedAt: Date
    var category: PersonalNoteCategory
    var tags: [String]
    var linkedNoteIDs: [UUID]
    var llmFeedbackStatus: LLMFeedbackStatus
    var llmFeedback: String
    var llmFeedbackUpdatedAt: Date?

    init(
        id: UUID,
        title: String,
        prompt: String,
        body: String,
        updatedAt: Date,
        category: PersonalNoteCategory,
        tags: [String] = [],
        linkedNoteIDs: [UUID] = [],
        llmFeedbackStatus: LLMFeedbackStatus = .none,
        llmFeedback: String = "",
        llmFeedbackUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.body = body
        self.updatedAt = updatedAt
        self.category = category
        self.tags = tags
        self.linkedNoteIDs = linkedNoteIDs
        self.llmFeedbackStatus = llmFeedbackStatus
        self.llmFeedback = llmFeedback
        self.llmFeedbackUpdatedAt = llmFeedbackUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        prompt = try container.decode(String.self, forKey: .prompt)
        body = try container.decode(String.self, forKey: .body)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        category = try container.decodeIfPresent(PersonalNoteCategory.self, forKey: .category) ?? .ideas
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        linkedNoteIDs = try container.decodeIfPresent([UUID].self, forKey: .linkedNoteIDs) ?? []
        llmFeedbackStatus = try container.decodeIfPresent(LLMFeedbackStatus.self, forKey: .llmFeedbackStatus) ?? .none
        llmFeedback = try container.decodeIfPresent(String.self, forKey: .llmFeedback) ?? ""
        llmFeedbackUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .llmFeedbackUpdatedAt)
    }
}

struct UserProfileRecord: Codable, Equatable, Sendable {
    let userID: UUID
    var headline: String
    var academicFocus: String
    var classYear: String
    var communityLabel: String
    var about: String
    var website: String
    var goals: [String]
    var notes: [ProfileNoteCard]
    var avatarImageData: Data?
    
    static func seed(for user: User) -> UserProfileRecord {
        UserProfileRecord(
            userID: user.id,
            headline: "Member",
            academicFocus: "",
            classYear: "",
            communityLabel: "Atlas",
            about: "Share what you are building, learning, and looking for.",
            website: "",
            goals: [
                "Meet aligned people",
                "Document ideas",
                "Stay accountable"
            ],
            notes: seedNotes(),
            avatarImageData: nil
        )
    }

    private static func seedNotes() -> [ProfileNoteCard] {
        let goals = ProfileNoteCard(
            id: UUID(),
            title: "Quarterly Goals",
            prompt: "Track what matters this season.",
            body: "What am I trying to accomplish in the next 30-90 days?",
            updatedAt: Date(),
            category: .goals,
            tags: ["focus", "accountability"]
        )
        let connections = ProfileNoteCard(
            id: UUID(),
            title: "People To Reconnect With",
            prompt: "Connect people, ideas, and opportunities.",
            body: "Who should I follow up with? Which conversations deserve a second pass?",
            updatedAt: Date(),
            category: .connections,
            tags: ["network", "follow-up"],
            linkedNoteIDs: [goals.id]
        )
        let startup = ProfileNoteCard(
            id: UUID(),
            title: "Atlas Personal System",
            prompt: "Capture the project that sits behind the work.",
            body: "What would a personal workspace need in order to help me reflect, connect ideas, and stay consistent?",
            updatedAt: Date(),
            category: .projects,
            tags: ["atlas", "product", "build"],
            linkedNoteIDs: [goals.id, connections.id]
        )
        let reflection = ProfileNoteCard(
            id: UUID(),
            title: "Weekly Reflection",
            prompt: "Notice patterns, not just events.",
            body: "Where did I make progress this week? Where did I hesitate? What should change next week?",
            updatedAt: Date(),
            category: .reflections,
            tags: ["review", "growth"],
            linkedNoteIDs: [goals.id, startup.id]
        )
        let idea = ProfileNoteCard(
            id: UUID(),
            title: "Ideas Worth Testing",
            prompt: "Keep the sparks before they disappear.",
            body: "Store half-formed concepts here before they get polished into projects or conversations.",
            updatedAt: Date(),
            category: .ideas,
            tags: ["ideas", "experiments"],
            linkedNoteIDs: [startup.id, reflection.id]
        )

        return [goals, connections, startup, reflection, idea]
    }
}

@MainActor
final class ProfileStore {
    static let shared = ProfileStore()

    private let keyPrefix = "atlas.profile."
    private var cachedProfiles: [UUID: UserProfileRecord] = [:]

    func loadProfile(for user: User) async -> UserProfileRecord {
        if let cached = cachedProfiles[user.id] {
            return cached
        }

        let userID = user.id
        let stored = await Task.detached(priority: .userInitiated) {
            Self.readPersistedProfile(for: userID)
        }.value

        guard let stored else {
            let seed = await migrateLegacyProfile(for: user) ?? UserProfileRecord.seed(for: user)
            cachedProfiles[user.id] = seed
            await persistFullProfile(seed)
            return seed
        }

        cachedProfiles[user.id] = stored
        return stored
    }

    func saveProfile(_ profile: UserProfileRecord) async {
        cachedProfiles[profile.userID] = profile
        let profileCopy = profile
        _ = await Task.detached(priority: .utility) {
            Self.writeMetadata(profileCopy)
            Self.writeAvatarData(profileCopy.avatarImageData, for: profileCopy.userID)
        }.value
    }

    func upsertNote(_ note: ProfileNoteCard, for userID: UUID) async {
        if var cached = cachedProfiles[userID] {
            if let index = cached.notes.firstIndex(where: { $0.id == note.id }) {
                cached.notes[index] = note
            } else {
                cached.notes.insert(note, at: 0)
            }
            cachedProfiles[userID] = cached
        }

        _ = await Task.detached(priority: .utility) {
            Self.writeNote(note, for: userID)
        }.value
    }

    func deleteNote(_ noteID: UUID, for userID: UUID) async {
        if var cached = cachedProfiles[userID] {
            cached.notes.removeAll { $0.id == noteID }
            cachedProfiles[userID] = cached
        }

        _ = await Task.detached(priority: .utility) {
            Self.deleteNoteFile(noteID: noteID, userID: userID)
        }.value
    }

    private func migrateLegacyProfile(for user: User) async -> UserProfileRecord? {
        let key = keyPrefix + user.id.uuidString
        guard let legacy = await Task.detached(priority: .userInitiated, operation: {
            Self.readLegacyProfile(forKey: key)
        }).value else {
            return nil
        }

        await persistFullProfile(legacy)
        UserDefaults.standard.removeObject(forKey: key)
        return legacy
    }

    private func persistFullProfile(_ profile: UserProfileRecord) async {
        cachedProfiles[profile.userID] = profile
        let profileCopy = profile
        _ = await Task.detached(priority: .utility) {
            Self.writeMetadata(profileCopy)
            Self.writeAvatarData(profileCopy.avatarImageData, for: profileCopy.userID)
            Self.replaceNotes(profileCopy.notes, for: profileCopy.userID)
        }.value
    }

    nonisolated private static func readPersistedProfile(for userID: UUID) -> UserProfileRecord? {
        guard let metadata = readMetadata(for: userID) else { return nil }
        let notes = readNotes(for: userID)
        let avatarData = readAvatarData(for: userID)
        return metadata.makeProfile(notes: notes, avatarImageData: avatarData)
    }

    nonisolated private static func writeMetadata(_ profile: UserProfileRecord) {
        let metadata = StoredUserProfileMetadata(profile: profile)
        guard let data = try? JSONEncoder().encode(metadata) else { return }
        let url = metadataURL(for: profile.userID)
        ensureParentDirectory(for: url)
        try? data.write(to: url, options: .atomic)
    }

    nonisolated private static func readMetadata(for userID: UUID) -> StoredUserProfileMetadata? {
        let url = metadataURL(for: userID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(StoredUserProfileMetadata.self, from: data)
    }

    nonisolated private static func writeAvatarData(_ data: Data?, for userID: UUID) {
        let url = avatarURL(for: userID)
        guard let data else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        ensureParentDirectory(for: url)
        try? data.write(to: url, options: .atomic)
    }

    nonisolated private static func readAvatarData(for userID: UUID) -> Data? {
        try? Data(contentsOf: avatarURL(for: userID))
    }

    nonisolated private static func writeNote(_ note: ProfileNoteCard, for userID: UUID) {
        guard let data = try? JSONEncoder().encode(note) else { return }
        let url = noteURL(for: userID, noteID: note.id)
        ensureParentDirectory(for: url)
        try? data.write(to: url, options: .atomic)
    }

    nonisolated private static func readNotes(for userID: UUID) -> [ProfileNoteCard] {
        let directory = notesDirectoryURL(for: userID)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(ProfileNoteCard.self, from: data)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    nonisolated private static func replaceNotes(_ notes: [ProfileNoteCard], for userID: UUID) {
        let directory = notesDirectoryURL(for: userID)
        try? FileManager.default.removeItem(at: directory)
        ensureDirectory(directory)

        for note in notes {
            writeNote(note, for: userID)
        }
    }

    nonisolated private static func deleteNoteFile(noteID: UUID, userID: UUID) {
        try? FileManager.default.removeItem(at: noteURL(for: userID, noteID: noteID))
    }

    nonisolated private static func readLegacyProfile(forKey key: String) -> UserProfileRecord? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserProfileRecord.self, from: data)
    }

    nonisolated private static func rootDirectoryURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent("Atlas", isDirectory: true)
            .appendingPathComponent("PersonalProfiles", isDirectory: true)
        ensureDirectory(url)
        return url
    }

    nonisolated private static func userDirectoryURL(for userID: UUID) -> URL {
        rootDirectoryURL().appendingPathComponent(userID.uuidString, isDirectory: true)
    }

    nonisolated private static func metadataURL(for userID: UUID) -> URL {
        userDirectoryURL(for: userID).appendingPathComponent("profile.json")
    }

    nonisolated private static func avatarURL(for userID: UUID) -> URL {
        userDirectoryURL(for: userID).appendingPathComponent("avatar.data")
    }

    nonisolated private static func notesDirectoryURL(for userID: UUID) -> URL {
        userDirectoryURL(for: userID).appendingPathComponent("notes", isDirectory: true)
    }

    nonisolated private static func noteURL(for userID: UUID, noteID: UUID) -> URL {
        notesDirectoryURL(for: userID).appendingPathComponent(noteID.uuidString).appendingPathExtension("json")
    }

    nonisolated private static func ensureParentDirectory(for url: URL) {
        ensureDirectory(url.deletingLastPathComponent())
    }

    nonisolated private static func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

private struct StoredUserProfileMetadata: Codable, Sendable {
    let userID: UUID
    var headline: String
    var academicFocus: String
    var classYear: String
    var communityLabel: String
    var about: String
    var website: String
    var goals: [String]

    init(profile: UserProfileRecord) {
        userID = profile.userID
        headline = profile.headline
        academicFocus = profile.academicFocus
        classYear = profile.classYear
        communityLabel = profile.communityLabel
        about = profile.about
        website = profile.website
        goals = profile.goals
    }

    func makeProfile(notes: [ProfileNoteCard], avatarImageData: Data?) -> UserProfileRecord {
        UserProfileRecord(
            userID: userID,
            headline: headline,
            academicFocus: academicFocus,
            classYear: classYear,
            communityLabel: communityLabel,
            about: about,
            website: website,
            goals: goals,
            notes: notes,
            avatarImageData: avatarImageData
        )
    }
}
