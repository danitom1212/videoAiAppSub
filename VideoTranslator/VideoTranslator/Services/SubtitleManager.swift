import Foundation

protocol SubtitleManagerDelegate: AnyObject {
    func subtitleDidUpdate(_ subtitle: Subtitle?)
}

class SubtitleManager {
    
    // MARK: - Properties
    weak var delegate: SubtitleManagerDelegate?
    private var subtitles: [Subtitle] = []
    private var translatedSubtitles: [Subtitle] = []
    private var currentTime: TimeInterval = 0
    private var targetLanguage: Language?
    private var showTranslation: Bool = false

    var currentSubtitles: [Subtitle] {
        subtitles
    }

    var currentTranslatedSubtitles: [Subtitle] {
        translatedSubtitles
    }
    
    // MARK: - Public Methods
    func setSubtitles(_ subtitles: [Subtitle]) {
        self.subtitles = subtitles
        self.translatedSubtitles = []
        self.showTranslation = false
        updateCurrentSubtitle()
    }
    
    func setTranslatedSubtitles(_ translatedSubtitles: [Subtitle]) {
        self.translatedSubtitles = translatedSubtitles
        self.showTranslation = true
        updateCurrentSubtitle()
    }
    
    func updateCurrentTime(_ time: TimeInterval) {
        currentTime = time
        updateCurrentSubtitle()
    }
    
    func setTargetLanguage(_ language: Language) {
        targetLanguage = language
    }
    
    func toggleTranslation() {
        showTranslation.toggle()
        updateCurrentSubtitle()
    }
    
    func getCurrentSubtitle() -> Subtitle? {
        let activeSubtitles = showTranslation ? translatedSubtitles : subtitles
        return activeSubtitles.first { $0.containsTime(currentTime) }
    }
    
    // MARK: - Private Methods
    private func updateCurrentSubtitle() {
        let subtitle = getCurrentSubtitle()
        delegate?.subtitleDidUpdate(subtitle)
    }
    
    // MARK: - Export/Import
    func exportSubtitles() -> Data? {
        let exportData = SubtitleExportData(
            originalSubtitles: subtitles,
            translatedSubtitles: translatedSubtitles,
            sourceLanguage: "en", // This should be tracked
            targetLanguage: targetLanguage?.code ?? "en"
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    func importSubtitles(from data: Data) -> Bool {
        do {
            let importData = try JSONDecoder().decode(SubtitleExportData.self, from: data)
            subtitles = importData.originalSubtitles
            translatedSubtitles = importData.translatedSubtitles
            targetLanguage = Language.language(for: importData.targetLanguage)
            showTranslation = !translatedSubtitles.isEmpty
            updateCurrentSubtitle()
            return true
        } catch {
            return false
        }
    }
    
    func exportToSRT() -> String? {
        let activeSubtitles = showTranslation ? translatedSubtitles : subtitles
        var srtContent = ""
        
        for (index, subtitle) in activeSubtitles.enumerated() {
            let startTime = formatSRTTime(subtitle.startTime)
            let endTime = formatSRTTime(subtitle.endTime)
            let text = subtitle.translatedText ?? subtitle.originalText
            
            srtContent += "\(index + 1)\n"
            srtContent += "\(startTime) --> \(endTime)\n"
            srtContent += "\(text)\n\n"
        }
        
        return srtContent
    }
    
    private func formatSRTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
}

// MARK: - SubtitleExportData
struct SubtitleExportData: Codable {
    let originalSubtitles: [Subtitle]
    let translatedSubtitles: [Subtitle]
    let sourceLanguage: String
    let targetLanguage: String
}

// MARK: - Learning Capabilities
extension SubtitleManager {
    
    func recordUserCorrection(originalSubtitle: Subtitle, correctedTranslation: String) {
        // Store user corrections for learning
        let correction = UserCorrection(
            originalText: originalSubtitle.originalText,
            originalTranslation: originalSubtitle.translatedText ?? "",
            correctedTranslation: correctedTranslation,
            sourceLanguage: "en", // Should be tracked
            targetLanguage: targetLanguage?.code ?? "en",
            timestamp: Date()
        )
        
        LearningManager.shared.recordCorrection(correction)
    }
    
    func getImprovedTranslation(for text: String) -> String? {
        guard let targetLanguage = targetLanguage else { return nil }
        return LearningManager.shared.getImprovedTranslation(
            for: text,
            sourceLanguage: "en",
            targetLanguage: targetLanguage.code
        )
    }
}

// MARK: - UserCorrection
struct UserCorrection: Codable {
    let originalText: String
    let originalTranslation: String
    let correctedTranslation: String
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date
}

// MARK: - LearningManager
class LearningManager {
    static let shared = LearningManager()
    
    private var corrections: [UserCorrection] = []
    private let userDefaults = UserDefaults.standard
    private let correctionsKey = "UserCorrections"
    
    private init() {
        loadCorrections()
    }
    
    func recordCorrection(_ correction: UserCorrection) {
        corrections.append(correction)
        saveCorrections()
    }
    
    func getImprovedTranslation(for text: String, sourceLanguage: String, targetLanguage: String) -> String? {
        // Find similar past corrections
        let similarCorrections = corrections.filter { correction in
            correction.originalText.lowercased() == text.lowercased() &&
            correction.sourceLanguage == sourceLanguage &&
            correction.targetLanguage == targetLanguage
        }
        
        // Return the most recent corrected translation
        return similarCorrections.sorted { $0.timestamp > $1.timestamp }.first?.correctedTranslation
    }
    
    private func loadCorrections() {
        if let data = userDefaults.data(forKey: correctionsKey),
           let savedCorrections = try? JSONDecoder().decode([UserCorrection].self, from: data) {
            corrections = savedCorrections
        }
    }
    
    private func saveCorrections() {
        if let data = try? JSONEncoder().encode(corrections) {
            userDefaults.set(data, forKey: correctionsKey)
        }
    }
    
    func getCorrectionsCount() -> Int {
        return corrections.count
    }
    
    func clearCorrections() {
        corrections.removeAll()
        userDefaults.removeObject(forKey: correctionsKey)
    }
}
