import Foundation

final class AppContainer {
    static let shared = AppContainer()

    let auth: AuthProviding
    let analytics: AnalyticsStore
    let database: SupabaseService

    private init() {
        // Toggle between mock and real auth
        #if DEBUG
        // Use mock auth for development/testing
        self.auth = MockAuthProvider()
        #else
        // Use real Supabase auth for production
        self.auth = SupabaseAuthProvider()
        #endif
        
        self.analytics = AnalyticsStore()
        self.database = SupabaseService.shared

        auth.restoreSession()
    }
    
    // Method to switch to real auth during development
    func enableRealAuth() {
        // This can be called from settings during development
        // In production, this would be handled by build configuration
    }
}
