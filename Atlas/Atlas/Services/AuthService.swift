import Foundation
import Supabase

final class AuthService {
    static let shared = AuthService()
    private var supabase: SupabaseClient { SupabaseService.shared.client }

    private init() {}

    func sendOTP(to phone: String) async throws {
        try await supabase.auth.signInWithOTP(phone: phone)
    }

    func verifyOTP(phone: String, token: String) async throws -> User {
        let response = try await supabase.auth.verifyOTP(
            phone: phone,
            token: token,
            type: .sms
        )
        return try await ensureUserProfile(for: response.user)
    }

    func currentUser() async -> User? {
        guard let authUser = supabase.auth.currentUser else { return nil }
        return try? await fetchProfile(for: authUser.id)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        KeychainManager.shared.delete(Constants.Keychain.userID)
        KeychainManager.shared.delete(Constants.Keychain.privateKey)
        KeychainManager.shared.delete(Constants.Keychain.publicKey)
    }

    private func ensureUserProfile(for authUser: Supabase.User) async throws -> User {
        if let existing = try? await fetchProfile(for: authUser.id) {
            return existing
        }
        let (publicKey, privateKey) = CryptoService.shared.generateKeypair()
        KeychainManager.shared.save(privateKey, for: Constants.Keychain.privateKey)
        KeychainManager.shared.save(publicKey, for: Constants.Keychain.publicKey)

        let newUser = User(
            id: authUser.id,
            phone: authUser.phone ?? "",
            displayName: "Member",
            avatarURL: nil,
            publicKey: publicKey,
            createdAt: Date()
        )
        try await supabase.from("users").insert(newUser).execute()
        return newUser
    }

    func fetchProfile(for userID: UUID) async throws -> User {
        try await supabase
            .from("users")
            .select()
            .eq("id", value: userID)
            .single()
            .execute()
            .value
    }

    func updateDisplayName(_ name: String, for userID: UUID) async throws {
        try await supabase
            .from("users")
            .update(["display_name": name])
            .eq("id", value: userID)
            .execute()
    }
}

enum AuthError: LocalizedError {
    case sessionMissing

    var errorDescription: String? {
        switch self {
        case .sessionMissing: return "Authentication failed. Please try again."
        }
    }
}
