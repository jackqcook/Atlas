import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class GroupDirectoryViewModel {
    var profiles: [UUID: CommunityProfileRecord] = [:]
    var artwork: [UUID: UIImage] = [:]
    var filteredJoinedGroups: [Group] = []
    var discoverMatches: [Group] = []
    var discoverableGroups: [Group] = []

    private var allKnownGroups: [Group] = []
    private var joinedGroups: [Group] = []
    private var joinedGroupIDs: Set<UUID> = []
    private var searchText = ""
    private var searchIndex: [UUID: String] = [:]

    func refresh(joinedGroups: [Group], discoverableGroups remoteGroups: [Group]) {
        self.joinedGroups = joinedGroups
        joinedGroupIDs = Set(joinedGroups.map(\.id))

        let merged = (joinedGroups + remoteGroups + MockCommunityCatalog.groups)
            .reduce(into: [UUID: Group]()) { partialResult, group in
                partialResult[group.id] = group
            }
        allKnownGroups = merged.values.sorted { $0.createdAt < $1.createdAt }

        let loadedProfiles = mergeProfiles(for: allKnownGroups)
        profiles = loadedProfiles
        artwork = Dictionary(
            uniqueKeysWithValues: loadedProfiles.compactMap { id, profile in
                guard let data = profile.logoImageData, let image = UIImage(data: data) else { return nil }
                return (id, image)
            }
        )

        searchIndex = Dictionary(
            uniqueKeysWithValues: allKnownGroups.map { group in
                let profile = loadedProfiles[group.id]
                let haystack = [
                    group.name,
                    group.description,
                    profile?.pitch ?? "",
                    profile?.territory.displayName ?? "",
                    profile?.focusTags.joined(separator: " ") ?? ""
                ]
                .joined(separator: " ")
                .lowercased()
                return (group.id, haystack)
            }
        )

        recomputeSearchResults()
    }

    func updateSearchText(_ text: String) {
        searchText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        recomputeSearchResults()
    }

    func profile(for group: Group) -> CommunityProfileRecord? {
        profiles[group.id]
    }

    func artwork(for groupID: UUID) -> UIImage? {
        artwork[groupID]
    }

    func isJoined(_ groupID: UUID) -> Bool {
        joinedGroupIDs.contains(groupID)
    }

    private func recomputeSearchResults() {
        if searchText.isEmpty {
            filteredJoinedGroups = joinedGroups
            discoverMatches = []
        } else {
            filteredJoinedGroups = joinedGroups.filter(matchesSearch)
            discoverMatches = discoverableGroups.filter { !joinedGroupIDs.contains($0.id) && matchesSearch($0) }
        }

        discoverableGroups = allKnownGroups.filter { profiles[$0.id]?.isDiscoverable ?? true }
        if !searchText.isEmpty {
            discoverMatches = discoverableGroups.filter { !joinedGroupIDs.contains($0.id) && matchesSearch($0) }
        }
    }

    private func matchesSearch(_ group: Group) -> Bool {
        guard !searchText.isEmpty else { return true }
        return searchIndex[group.id]?.contains(searchText) == true
    }

    private func mergeProfiles(for groups: [Group]) -> [UUID: CommunityProfileRecord] {
        var loaded = CommunityProfileStore.shared.loadProfiles(for: groups)
        for (id, profile) in MockCommunityCatalog.profiles {
            loaded[id] = profile
        }
        return loaded
    }
}
