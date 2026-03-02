import Foundation

class SupabaseService {
    static let shared = SupabaseService()
    
    private init() {
        // Mock implementation - no Supabase dependency
    }
    
    // MARK: - User Operations
    
    func updateUserProfile(_ user: AppUser) async throws {
        // Mock implementation
        print("Updating user profile for \(user.email)")
    }
    
    func getUserProfile(userId: String) async throws -> AppUser? {
        // Mock implementation
        return nil
    }
    
    func createUserProfile(_ user: AppUser) async throws {
        // Mock implementation
        print("Creating user profile for \(user.email)")
    }
    
    // MARK: - Session Operations
    
    func createSession(_ session: SessionEvent) async throws {
        // Mock implementation
        print("Creating session for user \(session.userId)")
    }
    
    func getSessionEvents(for userId: String) async throws -> [SessionEvent] {
        // Mock implementation
        return []
    }
    
    func getSessionStats(for userId: String) async throws -> SessionStats {
        // Mock implementation
        return SessionStats(
            totalSessions: 0,
            totalWatchTimeSeconds: 0,
            averageSessionDuration: 0,
            languagesUsed: Set(["en"])
        )
    }
    
    // MARK: - Translation Operations
    
    func saveTranslation(_ translation: TranslationEvent) async throws {
        // Mock implementation
        print("Saving translation for user \(translation.userId)")
    }
    
    func getTranslationHistory(for userId: String, limit: Int = 50) async throws -> [TranslationEvent] {
        // Mock implementation
        return []
    }
    
    // MARK: - Admin Operations
    
    func getAllUsers(limit: Int = 100) async throws -> [AppUser] {
        // Mock implementation
        return []
    }
    
    func getUserAnalytics(userId: String) async throws -> UserAnalytics {
        // Mock implementation
        return UserAnalytics(
            totalSessions: 0,
            totalWatchTimeSeconds: 0,
            averageSessionDuration: 0,
            languagesUsed: Set(["en"]),
            translationsCount: 0
        )
    }
}

// MARK: - Analytics Models

struct TranslationEvent {
    let id: String
    let userId: String
    let sourceLanguage: String
    let targetLanguage: String
    let originalText: String
    let translatedText: String
    let durationMs: Int
    let timestamp: Date
    
    init(userId: String, sourceLanguage: String, targetLanguage: String, originalText: String, translatedText: String, durationMs: Int) {
        self.id = UUID().uuidString
        self.userId = userId
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.originalText = originalText
        self.translatedText = translatedText
        self.durationMs = durationMs
        self.timestamp = Date()
    }
}

struct SessionEvent {
    let id: String
    let userId: String
    let type: SessionEventType
    let videoDurationSeconds: Double
    let language: String
    let timestamp: Date
    
    init(userId: String, type: SessionEventType, videoDurationSeconds: Double, language: String) {
        self.id = UUID().uuidString
        self.userId = userId
        self.type = type
        self.videoDurationSeconds = videoDurationSeconds
        self.language = language
        self.timestamp = Date()
    }
}

enum SessionEventType: String {
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case translation = "translation"
    case languageChange = "language_change"
}

struct SessionStats {
    let totalSessions: Int
    let totalWatchTimeSeconds: Double
    let averageSessionDuration: Double
    let languagesUsed: Set<String>
    
    init(totalSessions: Int = 0, totalWatchTimeSeconds: Double = 0, averageSessionDuration: Double = 0, languagesUsed: Set<String> = Set(["en"])) {
        self.totalSessions = totalSessions
        self.totalWatchTimeSeconds = totalWatchTimeSeconds
        self.averageSessionDuration = averageSessionDuration
        self.languagesUsed = languagesUsed
    }
}

struct GlobalAnalytics {
    let totalTranslations: Int
    let totalSessions: Int
    let uniqueUsers: Int
    let topLanguages: [(language: String, count: Int)]
    
    init(totalTranslations: Int = 0, totalSessions: Int = 0, uniqueUsers: Int = 0, topLanguages: [(language: String, count: Int)] = []) {
        self.totalTranslations = totalTranslations
        self.totalSessions = totalSessions
        self.uniqueUsers = uniqueUsers
        self.topLanguages = topLanguages
    }
}
