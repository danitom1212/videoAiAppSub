import Foundation

enum AnalyticsEventType: String, Codable {
    case translation
    case signIn
    case signUp
    case signOut
}

struct AnalyticsEvent: Codable {
    let id: UUID
    let type: AnalyticsEventType
    let userEmail: String?
    let timestamp: Date

    let sourceLanguage: String?
    let targetLanguage: String?
    let provider: String?

    init(id: UUID = UUID(), type: AnalyticsEventType, userEmail: String?, timestamp: Date = Date(), sourceLanguage: String? = nil, targetLanguage: String? = nil, provider: String? = nil) {
        self.id = id
        self.type = type
        self.userEmail = userEmail
        self.timestamp = timestamp
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.provider = provider
    }
}
