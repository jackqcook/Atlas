import Foundation

enum CommunityTerritory: String, Codable, CaseIterable, Sendable {
    case builders
    case local
    case ideas
    case culture
    case growth

    var displayName: String {
        switch self {
        case .builders: return "Builders"
        case .local: return "Local"
        case .ideas: return "Ideas"
        case .culture: return "Culture"
        case .growth: return "Growth"
        }
    }

    var keywords: [String] {
        switch self {
        case .builders: return ["build", "builder", "product", "startup", "engineering", "ai", "tech"]
        case .local: return ["local", "city", "neighborhood", "school", "campus", "byu", "utah"]
        case .ideas: return ["research", "learning", "think", "ideas", "science", "math"]
        case .culture: return ["art", "music", "food", "books", "film", "culture", "creative"]
        case .growth: return ["health", "fitness", "reflection", "growth", "wellness", "mindset"]
        }
    }
}

struct CommunityProfileRecord: Codable, Equatable, Sendable {
    let groupID: UUID
    var territory: CommunityTerritory
    var pitch: String
    var focusTags: [String]
    var donationURL: String
    var isDiscoverable: Bool
    var logoImageData: Data?

    static func seed(for group: Group) -> CommunityProfileRecord {
        let territory = inferTerritory(from: "\(group.name) \(group.description)".lowercased())
        let tags = defaultTags(for: territory, group: group)
        return CommunityProfileRecord(
            groupID: group.id,
            territory: territory,
            pitch: group.description.isEmpty ? "A community inside Atlas." : group.description,
            focusTags: tags,
            donationURL: "",
            isDiscoverable: true,
            logoImageData: nil
        )
    }

    private static func inferTerritory(from text: String) -> CommunityTerritory {
        let scored = CommunityTerritory.allCases.map { territory in
            let score = territory.keywords.reduce(0) { partial, keyword in
                partial + (text.contains(keyword) ? 1 : 0)
            }
            return (territory, score)
        }
        return scored.max(by: { $0.1 < $1.1 })?.0 ?? .builders
    }

    private static func defaultTags(for territory: CommunityTerritory, group: Group) -> [String] {
        let nameTag = group.name
            .lowercased()
            .split(separator: " ")
            .first
            .map(String.init)

        let territoryTag: String
        switch territory {
        case .builders: territoryTag = "builders"
        case .local: territoryTag = "local"
        case .ideas: territoryTag = "ideas"
        case .culture: territoryTag = "culture"
        case .growth: territoryTag = "growth"
        }

        return [territoryTag, nameTag].compactMap { $0 }
    }
}

@MainActor
final class CommunityProfileStore {
    static let shared = CommunityProfileStore()

    private let keyPrefix = "atlas.community.profile."
    private let requestPrefix = "atlas.community.request."

    func loadProfile(for group: Group) -> CommunityProfileRecord {
        let key = keyPrefix + group.id.uuidString
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode(CommunityProfileRecord.self, from: data) else {
            let seed = CommunityProfileRecord.seed(for: group)
            saveProfile(seed)
            return seed
        }
        return stored
    }

    func loadProfiles(for groups: [Group]) -> [UUID: CommunityProfileRecord] {
        Dictionary(uniqueKeysWithValues: groups.map { ($0.id, loadProfile(for: $0)) })
    }

    func saveProfile(_ profile: CommunityProfileRecord) {
        let key = keyPrefix + profile.groupID.uuidString
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func hasRequestedJoin(userID: UUID, groupID: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: requestPrefix + userID.uuidString + "." + groupID.uuidString)
    }

    func setRequestedJoin(_ requested: Bool, userID: UUID, groupID: UUID) {
        UserDefaults.standard.set(requested, forKey: requestPrefix + userID.uuidString + "." + groupID.uuidString)
    }
}
