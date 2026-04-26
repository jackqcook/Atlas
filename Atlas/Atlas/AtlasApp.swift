import SwiftUI

private let atlasRed = Color(red: 0.863, green: 0.078, blue: 0.235)

@main
struct AtlasApp: App {
    @State private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            SwiftUI.Group {
                if authVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if authVM.isAuthenticated {
                    MainTabView()
                        .environment(authVM)
                } else {
                    PhoneEntryView()
                        .environment(authVM)
                }
            }
            .tint(atlasRed)
            .task {
                await authVM.checkSession()
            }
        }
    }
}
