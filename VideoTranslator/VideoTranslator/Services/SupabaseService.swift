import Foundation

class SupabaseService {
    static let shared = SupabaseService()
    
    // private let client: SupabaseClient // Removed - no Supabase dependency
    
    private init() {
        // TODO: Replace with your actual Supabase URL and Anon Key
        // self.client = SupabaseClient(...) // Removed - no Supabase dependency
    }
    
    // MARK: - User Operations
    
    func updateUserProfile(_ user: AppUser) async throws {
        let userData: [String: Any] = [
            "email": user.email,
            "display_name": user.displayName,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        _ = try await client.database
            .from("users")
            .update(userData)
            .eq("id", value: user.id)
            .execute()
    }
    
    func getUserProfile(userId: String) async throws -> AppUser? {
        let response = try await client.database
            .from("users")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
        
        guard let data = response.data,
              let dict = data as? [String: Any],
              let email = dict["email"] as? String,
              let displayName = dict["display_name"] as? String else {
            return nil
        }
        
        let formatter = ISO8601DateFormatter()
        
        return AppUser(
            id: dict["id"] as? String ?? userId,
            email: email,
            displayName: displayName,
            isAnonymous: dict["is_anonymous"] as? Bool ?? false,
            createdAt: formatter.date(from: dict["created_at"] as? String ?? "") ?? Date(),
            lastLoginAt: formatter.date(from: dict["last_login_at"] as? String ?? "") ?? Date()
        )
    }
    
    // MARK: - Translation Analytics
    
    func saveTranslationEvent(_ event: TranslationEvent) async throws {
        let eventData: [String: Any] = [
            "id": event.id,
            "user_id": event.userId,
            "source_language": event.sourceLanguage,
            "target_language": event.targetLanguage,
            "original_text": event.originalText,
            "translated_text": event.translatedText,
            "duration_ms": event.durationMs,
            "created_at": ISO8601DateFormatter().string(from: event.timestamp)
        ]
        
        _ = try await client.database
            .from("translation_events")
            .insert(eventData)
            .execute()
    }
    
    func getTranslationHistory(for userId: String, limit: Int = 50) async throws -> [TranslationEvent] {
        let response = try await client.database
            .from("translation_events")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
        
        guard let data = response.data as? [[String: Any]] else {
            return []
        }
        
        let formatter = ISO8601DateFormatter()
        return data.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let userId = dict["user_id"] as? String,
                  let sourceLanguage = dict["source_language"] as? String,
                  let targetLanguage = dict["target_language"] as? String,
                  let originalText = dict["original_text"] as? String,
                  let translatedText = dict["translated_text"] as? String,
                  let durationMs = dict["duration_ms"] as? Int,
                  let createdAtString = dict["created_at"] as? String,
                  let createdAt = formatter.date(from: createdAtString) else {
                return nil
            }
            
            return TranslationEvent(
                id: id,
                userId: userId,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                originalText: originalText,
                translatedText: translatedText,
                durationMs: durationMs,
                timestamp: createdAt
            )
        }
    }
    
    // MARK: - Session Analytics
    
    func saveSessionEvent(_ event: SessionEvent) async throws {
        let eventData: [String: Any] = [
            "id": event.id,
            "user_id": event.userId,
            "event_type": event.type.rawValue,
            "video_duration_seconds": event.videoDurationSeconds,
            "language": event.language,
            "created_at": ISO8601DateFormatter().string(from: event.timestamp)
        ]
        
        _ = try await client.database
            .from("session_events")
            .insert(eventData)
            .execute()
    }
    
    func getSessionStats(for userId: String, fromDate: Date? = nil) async throws -> SessionStats {
        let query = client.database
            .from("session_events")
            .select()
            .eq("user_id", value: userId)
        
        if let fromDate = fromDate {
            let formatter = ISO8601DateFormatter()
            query = query.gte("created_at", value: formatter.string(from: fromDate))
        }
        
        let response = try await query.execute()
        
        guard let data = response.data as? [[String: Any]] else {
            return SessionStats()
        }
        
        let formatter = ISO8601DateFormatter()
        let events = data.compactMap { dict -> SessionEvent? in
            guard let id = dict["id"] as? String,
                  let userId = dict["user_id"] as? String,
                  let eventTypeString = dict["event_type"] as? String,
                  let eventType = SessionEventType(rawValue: eventTypeString),
                  let videoDurationSeconds = dict["video_duration_seconds"] as? Double,
                  let language = dict["language"] as? String,
                  let createdAtString = dict["created_at"] as? String,
                  let createdAt = formatter.date(from: createdAtString) else {
                return nil
            }
            
            return SessionEvent(
                id: id,
                userId: userId,
                type: eventType,
                videoDurationSeconds: videoDurationSeconds,
                language: language,
                timestamp: createdAt
            )
        }
        
        return SessionStats(events: events)
    }
    
    // MARK: - Admin Operations
    
    func getAllUsers(limit: Int = 100) async throws -> [AppUser] {
        let response = try await client.database
            .from("users")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
        
        guard let data = response.data as? [[String: Any]] else {
            return []
        }
        
        let formatter = ISO8601DateFormatter()
        return data.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let email = dict["email"] as? String,
                  let displayName = dict["display_name"] as? String else {
                return nil
            }
            
            return AppUser(
                id: id,
                email: email,
                displayName: displayName,
                isAnonymous: dict["is_anonymous"] as? Bool ?? false,
                createdAt: formatter.date(from: dict["created_at"] as? String ?? "") ?? Date(),
                lastLoginAt: formatter.date(from: dict["last_login_at"] as? String ?? "") ?? Date()
            )
        }
    }
    
    func getGlobalAnalytics(fromDate: Date? = nil) async throws -> GlobalAnalytics {
        let translationQuery = client.database
            .from("translation_events")
            .select()
        
        let sessionQuery = client.database
            .from("session_events")
            .select()
        
        if let fromDate = fromDate {
            let formatter = ISO8601DateFormatter()
            let dateString = formatter.string(from: fromDate)
            translationQuery = translationQuery.gte("created_at", value: dateString)
            sessionQuery = sessionQuery.gte("created_at", value: dateString)
        }
        
        async let translationsResponse = translationQuery.execute()
        async let sessionsResponse = sessionQuery.execute()
        
        let (translationsData, sessionsData) = try await (translationsResponse, sessionsResponse)
        
        let translations = translationsData.data as? [[String: Any]] ?? []
        let sessions = sessionsData.data as? [[String: Any]] ?? []
        
        return GlobalAnalytics(
            totalTranslations: translations.count,
            totalSessions: sessions.count,
            uniqueUsers: Set((sessions.compactMap { $0["user_id"] as? String })).count,
            topLanguages: calculateTopLanguages(from: translations)
        )
    }
    
    // MARK: - Private Helpers
    
    private func calculateTopLanguages(from translations: [[String: Any]]) -> [(language: String, count: Int)] {
        var languageCounts: [String: Int] = [:]
        
        for translation in translations {
            if let targetLanguage = translation["target_language"] as? String {
                languageCounts[targetLanguage, default: 0] += 1
            }
        }
        
        return languageCounts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
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
    
    init(events: [SessionEvent] = []) {
        let startEvents = events.filter { $0.type == .sessionStart }
        let endEvents = events.filter { $0.type == .sessionEnd }
        
        self.totalSessions = startEvents.count
        self.totalWatchTimeSeconds = endEvents.reduce(0) { $0 + $1.videoDurationSeconds }
        self.averageSessionDuration = totalSessions > 0 ? totalWatchTimeSeconds / Double(totalSessions) : 0
        self.languagesUsed = Set(events.map { $0.language })
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
