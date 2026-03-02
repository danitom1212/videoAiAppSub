import Foundation

final class AnalyticsStore {

    private enum Keys {
        static let events = "AnalyticsStore.Events"
    }

    private let defaults: UserDefaults
    private(set) var events: [AnalyticsEvent] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func track(_ event: AnalyticsEvent) {
        events.append(event)
        save()
        NotificationCenter.default.post(name: .analyticsUpdated, object: nil)
    }

    func clear() {
        events.removeAll()
        defaults.removeObject(forKey: Keys.events)
        NotificationCenter.default.post(name: .analyticsUpdated, object: nil)
    }

    func topTargetLanguages(limit: Int = 5) -> [(code: String, count: Int)] {
        let counts = events
            .filter { $0.type == .translation }
            .compactMap { $0.targetLanguage }
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }

        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    func translationsCountLast24h() -> Int {
        let from = Date().addingTimeInterval(-24 * 60 * 60)
        return events.filter { $0.type == .translation && $0.timestamp >= from }.count
    }

    func activeUsersLast24h() -> Int {
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
