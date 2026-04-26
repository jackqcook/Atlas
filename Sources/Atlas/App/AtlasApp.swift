import SwiftUI

@main
struct AtlasApp: App {
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if authVM.isAuthenticated {
                    MainTabView()
                        .environmentObject(authVM)
                } else {
                    PhoneEntryView()
                        .environmentObject(authVM)
                }
            }
            .task {
                await authVM.checkSession()
            }
        }
    }
}
