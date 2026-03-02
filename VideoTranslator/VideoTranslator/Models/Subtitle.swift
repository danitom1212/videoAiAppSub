import Foundation

struct Subtitle {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let originalText: String
    var translatedText: String?
    let confidence: Float?
    
    init(id: UUID = UUID(), startTime: TimeInterval, endTime: TimeInterval, originalText: String, translatedText: String? = nil, confidence: Float? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.originalText = originalText
        self.translatedText = translatedText
        self.confidence = confidence
    }
    
    var duration: TimeInterval {
        return endTime - startTime
    }
    
    func containsTime(_ time: TimeInterval) -> Bool {
        return time >= startTime && time <= endTime
    }
    
    func withTranslation(_ translation: String) -> Subtitle {
        return Subtitle(
            id: id,
            startTime: startTime,
            endTime: endTime,
            originalText: originalText,
            translatedText: translation,
            confidence: confidence
        )
    }
}

extension Subtitle: Codable {
    enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, originalText, translatedText, confidence
    }
}
