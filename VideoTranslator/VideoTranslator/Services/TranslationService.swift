import Foundation

protocol TranslationServiceDelegate: AnyObject {
    func translationDidStart()
    func translationDidComplete(with translatedSubtitles: [Subtitle])
    func translationDidFail(with error: Error)
}

class TranslationService {
    
    // MARK: - Properties
    weak var delegate: TranslationServiceDelegate?
    private var sourceLanguage: Language = Language.language(for: "en")!
    private var targetLanguage: Language = Language.language(for: "es")!
    private var apiKey: String
    
    // MARK: - Initialization
    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "OpenAI_API_Key") ?? ""
    }

    func refreshSettings() {
        apiKey = UserDefaults.standard.string(forKey: "OpenAI_API_Key") ?? ""
    }
    
    // MARK: - Public Methods
    func setLanguages(source: Language, target: Language) {
        sourceLanguage = source
        targetLanguage = target
    }
    
    func translateSubtitles(_ subtitles: [Subtitle]) {
        delegate?.translationDidStart()
        
        // Process subtitles in batches to avoid API rate limits
        let batchSize = 10
        var translatedSubtitles: [Subtitle] = []
        var currentIndex = 0
        
        func translateNextBatch() {
            guard currentIndex < subtitles.count else {
                DispatchQueue.main.async {
                    self.delegate?.translationDidComplete(with: translatedSubtitles)
                }
                return
            }
            
            let endIndex = min(currentIndex + batchSize, subtitles.count)
            let batch = Array(subtitles[currentIndex..<endIndex])
            
            translateBatch(batch) { [weak self] result in
                switch result {
                case .success(let translatedBatch):
                    translatedSubtitles.append(contentsOf: translatedBatch)
                    currentIndex = endIndex
                    
                    // Add delay to respect API rate limits
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        translateNextBatch()
                    }
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.delegate?.translationDidFail(with: error)
                    }
                }
            }
        }
        
        translateNextBatch()
    }
    
    // MARK: - Private Methods
    private func translateBatch(_ batch: [Subtitle], completion: @escaping (Result<[Subtitle], Error>) -> Void) {
        // Prepare texts for translation
        let texts = batch.map { $0.originalText }
        
        // Choose translation method based on availability
        if !apiKey.isEmpty {
            translateWithOpenAI(batch: batch, texts: texts, completion: completion)
        } else {
            translateWithPassthrough(batch: batch, texts: texts, completion: completion)
        }
    }
    
    private func translateWithOpenAI(batch: [Subtitle], texts: [String], completion: @escaping (Result<[Subtitle], Error>) -> Void) {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create prompt for translation
        let prompt = """
        Translate the following texts from \(sourceLanguage.name) to \(targetLanguage.name). 
        Return only the translations, one per line, in the same order:
        
        \(texts.joined(separator: "\n"))
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a professional translator. Translate the given text accurately while preserving the original meaning and tone."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 2000,
            "temperature": 0.3
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(TranslationError.invalidRequest))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(TranslationError.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    let translations = content.components(separatedBy: .newlines)
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                    let translatedSubtitles: [Subtitle] = batch.enumerated().map { index, subtitle in
                        let translation = index < translations.count ? translations[index] : subtitle.originalText
                        return subtitle.withTranslation(translation)
                    }
                    
                    completion(.success(translatedSubtitles))
                } else {
                    completion(.failure(TranslationError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func translateWithPassthrough(batch: [Subtitle], texts: [String], completion: @escaping (Result<[Subtitle], Error>) -> Void) {
        let translatedSubtitles = batch.map { $0.withTranslation($0.originalText) }
        completion(.success(translatedSubtitles))
    }
}

// MARK: - TranslationError
enum TranslationError: LocalizedError {
    case invalidRequest
    case noData
    case invalidResponse
    case translationFailed
    case apiKeyMissing
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid translation request."
        case .noData:
            return "No data received from translation service."
        case .invalidResponse:
            return "Invalid response from translation service."
        case .translationFailed:
            return "Translation failed."
        case .apiKeyMissing:
            return "Translation API key is missing. Please configure your API key."
        case .rateLimitExceeded:
            return "Translation rate limit exceeded. Please try again later."
        }
    }
}
