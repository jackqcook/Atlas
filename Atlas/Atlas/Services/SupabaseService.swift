import Foundation
import Supabase

final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    var isConfigured: Bool {
        Constants.Supabase.url != "YOUR_SUPABASE_URL"
    }

    private init() {
        // Use a dummy URL in dev so the app doesn't crash before credentials are set.
        let url = URL(string: Constants.Supabase.url)
            ?? URL(string: "https://placeholder.supabase.co")!
        client = SupabaseClient(supabaseURL: url, supabaseKey: Constants.Supabase.anonKey)
    }
}
