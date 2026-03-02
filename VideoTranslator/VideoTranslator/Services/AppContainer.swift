import Foundation

final class AppContainer {
    static let shared = AppContainer()

    let auth: AuthProviding
    let analytics: AnalyticsStore

    private init() {
        self.auth = MockAuthProvider()
        self.analytics = AnalyticsStore()

        auth.restoreSession()
    }
}
