import Foundation

enum PersonalNoteCategory: String, Codable, CaseIterable, Sendable {
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

struct ProfileNoteCard: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var prompt: String
    var body: String
    var updatedAt: Date
    var category: PersonalNoteCategory
    var tags: [String]
    var linkedNoteIDs: [UUID]

    init(
        id: UUID,
        title: String,
        prompt: String,
        body: String,
        updatedAt: Date,
        category: PersonalNoteCategory,
        tags: [String] = [],
        linkedNoteIDs: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.body = body
        self.updatedAt = updatedAt
        self.category = category
        self.tags = tags
        self.linkedNoteIDs = linkedNoteIDs
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

    func loadProfile(for user: User) -> UserProfileRecord {
        let key = keyPrefix + user.id.uuidString

        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode(UserProfileRecord.self, from: data) else {
            let seed = UserProfileRecord.seed(for: user)
            saveProfile(seed)
            return seed
        }

        return stored
    }

    func saveProfile(_ profile: UserProfileRecord) {
        let key = keyPrefix + profile.userID.uuidString
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
