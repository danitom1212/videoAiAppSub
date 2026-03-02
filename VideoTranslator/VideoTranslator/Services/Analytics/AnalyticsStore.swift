import Foundation

final class AnalyticsStore {

    private enum Keys {
        static let events = "AnalyticsStore.Events"
        static let useSupabase = "AnalyticsStore.UseSupabase"
    }

    private let defaults: UserDefaults
    private(set) var events: [AnalyticsEvent] = []
    private let supabase = SupabaseService.shared
    
    var useSupabase: Bool {
        get { defaults.bool(forKey: Keys.useSupabase) }
        set { 
            defaults.set(newValue, forKey: Keys.useSupabase)
            if newValue {
                migrateLocalEventsToSupabase()
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func track(_ event: AnalyticsEvent) {
        events.append(event)
        
        // Save locally
        save()
        
        // Also save to Supabase if enabled
        if useSupabase {
            Task {
                do {
                    if let translationEvent = convertToTranslationEvent(event) {
                        try await supabase.saveTranslationEvent(translationEvent)
                    }
                    if let sessionEvent = convertToSessionEvent(event) {
                        try await supabase.saveSessionEvent(sessionEvent)
                    }
                } catch {
                    print("Failed to save event to Supabase: \(error)")
                    // Continue with local storage as fallback
                }
            }
        }
        
        NotificationCenter.default.post(name: .analyticsUpdated, object: nil)
    }

    func clear() {
        events.removeAll()
        defaults.removeObject(forKey: Keys.events)
        NotificationCenter.default.post(name: .analyticsUpdated, object: nil)
    }

    func topTargetLanguages(limit: Int = 5) -> [(code: String, count: Int)] {
        if useSupabase {
            // For now, use local data. In a real app, you'd fetch from Supabase
            return getTopTargetLanguagesFromLocal(limit: limit)
        } else {
            return getTopTargetLanguagesFromLocal(limit: limit)
        }
    }

    func translationsCountLast24h() -> Int {
        if useSupabase {
            // For now, use local data. In a real app, you'd fetch from Supabase
            return getTranslationsCountFromLocal()
        } else {
            return getTranslationsCountFromLocal()
        }
    }

    func activeUsersLast24h() -> Int {
        if useSupabase {
            // For now, use local data. In a real app, you'd fetch from Supabase
            return getActiveUsersFromLocal()
        } else {
            return getActiveUsersFromLocal()
        }
    }
    
    // MARK: - Supabase Integration
    
    func enableSupabaseAnalytics() {
        useSupabase = true
    }
    
    func disableSupabaseAnalytics() {
        useSupabase = false
    }
    
    private func migrateLocalEventsToSupabase() {
        Task {
            for event in events {
                do {
                    if let translationEvent = convertToTranslationEvent(event) {
                        try await supabase.saveTranslationEvent(translationEvent)
                    }
                    if let sessionEvent = convertToSessionEvent(event) {
                        try await supabase.saveSessionEvent(sessionEvent)
                    }
                } catch {
                    print("Failed to migrate event to Supabase: \(error)")
                }
            }
        }
    }
    
    private func convertToTranslationEvent(_ event: AnalyticsEvent) -> TranslationEvent? {
        guard event.type == .translation,
              let userId = AppContainer.shared.auth.currentUser?.id,
              let sourceLanguage = event.sourceLanguage,
              let targetLanguage = event.targetLanguage else {
            return nil
        }
        
        return TranslationEvent(
            userId: userId,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            originalText: event.originalText ?? "",
            translatedText: event.translatedText ?? "",
            durationMs: event.durationMs ?? 0
        )
    }
    
    private func convertToSessionEvent(_ event: AnalyticsEvent) -> SessionEvent? {
        guard let userId = AppContainer.shared.auth.currentUser?.id else { return nil }
        
        let eventType: SessionEventType?
        switch event.type {
        case .signIn:
            eventType = .sessionStart
        case .signOut:
            eventType = .sessionEnd
        case .translation:
            eventType = .translation
        case .languageChange:
            eventType = .languageChange
        default:
            eventType = nil
        }
        
        guard let sessionEventType = eventType else { return nil }
        
        return SessionEvent(
            userId: userId,
            type: sessionEventType,
            videoDurationSeconds: event.videoDurationSeconds ?? 0,
            language: event.targetLanguage ?? "en"
        )
    }

    // MARK: - Local Methods
    
    private func getTopTargetLanguagesFromLocal(limit: Int) -> [(code: String, count: Int)] {
        let counts = events
            .filter { $0.type == .translation }
            .compactMap { $0.targetLanguage }
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }

        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    private func getTranslationsCountFromLocal() -> Int {
        let from = Date().addingTimeInterval(-24 * 60 * 60)
        return events.filter { $0.type == .translation && $0.timestamp >= from }.count
    }

    private func getActiveUsersFromLocal() -> Int {
        let from = Date().addingTimeInterval(-24 * 60 * 60)
        let emails = events
            .filter { ($0.type == .translation || $0.type == .signIn) && $0.timestamp >= from }
            .compactMap { $0.userEmail }
        return Set(emails).count
    }

    private func load() {
        guard let data = defaults.data(forKey: Keys.events) else {
            events = []
            return
        }
        events = (try? JSONDecoder().decode([AnalyticsEvent].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: Keys.events)
    }
}

extension Notification.Name {
    static let analyticsUpdated = Notification.Name("AnalyticsUpdated")
}
