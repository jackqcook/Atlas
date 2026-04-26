import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    @Published var phase: AuthPhase = .phoneEntry

    private let authService = AuthService.shared

    enum AuthPhase: Equatable {
        case phoneEntry
        case otpVerification(phone: String)
    }

    func checkSession() async {
        isLoading = true
        if let user = await authService.currentUser() {
            currentUser = user
            isAuthenticated = true
        }
        isLoading = false
    }

    func sendOTP(phone: String) async {
        isLoading = true
        error = nil
        do {
            let formatted = normalized(phone)
            try await authService.sendOTP(to: formatted)
            phase = .otpVerification(phone: formatted)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func verifyOTP(code: String) async {
        guard case .otpVerification(let phone) = phase else { return }
        isLoading = true
        error = nil
        do {
            let user = try await authService.verifyOTP(phone: phone, token: code)
            currentUser = user
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func updateDisplayName(_ name: String) async {
        guard let userID = currentUser?.id else { return }
        do {
            try await authService.updateDisplayName(name, for: userID)
            currentUser?.displayName = name
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signOut() async {
        try? await authService.signOut()
        currentUser = nil
        isAuthenticated = false
        phase = .phoneEntry
    }

    private func normalized(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        return digits.hasPrefix("1") ? "+\(digits)" : "+1\(digits)"
    }
}
