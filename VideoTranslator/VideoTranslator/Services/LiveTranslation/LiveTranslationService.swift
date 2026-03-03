import Foundation
import AVFoundation
import ReplayKit
import Combine
import Speech

// MARK: - Live Translation Service
class LiveTranslationService {
    // MARK: - Properties
    private let aiService: AIService
    private let transcriptionService: TranscriptionService
    private let translationService: TranslationService
    private let audioEngine: AVAudioEngine
    private let speechRecognizer: SFSpeechRecognizer
    private var screenRecorder: RPScreenRecorder?
    
    // MARK: - State
    private var isRecording = false
    private var isTranslating = false
    private var currentMode: LiveTranslationMode = .audio
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Publishers
    private var translationSubject = PassthroughSubject<LiveTranslationResult, Never>()
    var translationPublisher: AnyPublisher<LiveTranslationResult, Never> {
        translationSubject.eraseToAnyPublisher()
    }
    
    private var stateSubject = CurrentValueSubject<LiveTranslationState, Never>(.idle)
    var statePublisher: AnyPublisher<LiveTranslationState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init(aiService: AIService, transcriptionService: TranscriptionService, translationService: TranslationService) {
        self.aiService = aiService
        self.transcriptionService = transcriptionService
        self.translationService = translationService
        self.audioEngine = AVAudioEngine()
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        
        setupAudioSession()
        setupPermissions()
    }
    
    // MARK: - Public Methods
    
    func startLiveTranslation(mode: LiveTranslationMode, sourceLanguage: Language, targetLanguage: Language) async throws {
        guard !isRecording else {
            throw LiveTranslationError.alreadyRecording
        }
        
        self.currentMode = mode
        stateSubject.send(.starting)
        
        switch mode {
        case .audio:
            try await startAudioTranslation(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        case .screen:
            try await startScreenTranslation(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        case .pictureInPicture:
            try await startPictureInPictureTranslation(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        }
        
        isRecording = true
        isTranslating = true
        stateSubject.send(.active)
    }
    
    func stopLiveTranslation() {
        guard isRecording else { return }
        
        stateSubject.send(.stopping)
        
        switch currentMode {
        case .audio:
            stopAudioTranslation()
        case .screen:
            stopScreenTranslation()
        case .pictureInPicture:
            stopPictureInPictureTranslation()
        }
        
        isRecording = false
        isTranslating = false
        stateSubject.send(.idle)
    }
    
    func pauseTranslation() {
        guard isTranslating else { return }
        isTranslating = false
        stateSubject.send(.paused)
    }
    
    func resumeTranslation() {
        guard isRecording && !isTranslating else { return }
        isTranslating = true
        stateSubject.send(.active)
    }
    
    // MARK: - Audio Translation
    private func startAudioTranslation(sourceLanguage: Language, targetLanguage: Language) async throws {
        // Request microphone permission
        let permission = await AVAudioSession.sharedInstance.requestRecordPermission()
        guard permission else {
            throw LiveTranslationError.microphonePermissionDenied
        }
        
        // Request speech recognition permission
        let speechPermission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechPermission else {
            throw LiveTranslationError.speechRecognitionPermissionDenied
        }
        
        // Setup audio session
        try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try audioSession.setActive(true)
        
        // Start speech recognition
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Process speech recognition results
        speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            guard let result = result else {
                if let error = error {
                    self.handleTranslationError(error)
                }
                return
            }
            
            let bestTranscription = result.bestTranscription.formattedString
            Task {
                await self.processAudioTranscription(bestTranscription, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            }
        }
    }
    
    private func stopAudioTranslation() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        do {
            try audioSession.setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    private func processAudioTranscription(_ transcription: String, sourceLanguage: Language, targetLanguage: Language) async {
        guard isTranslating else { return }
        
        do {
            let translation = try await translationService.translateText(
                transcription,
                from: sourceLanguage,
                to: targetLanguage
            )
            
            let result = LiveTranslationResult(
                type: .audio,
                originalText: transcription,
                translatedText: translation.text,
                confidence: translation.confidence,
                timestamp: Date(),
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            
            translationSubject.send(result)
            
        } catch {
            handleTranslationError(error)
        }
    }
    
    // MARK: - Screen Translation
    private func startScreenTranslation(sourceLanguage: Language, targetLanguage: Language) async throws {
        // Check if screen recording is available
        guard RPScreenRecorder.shared().isAvailable else {
            throw LiveTranslationError.screenRecordingNotAvailable
        }
        
        screenRecorder = RPScreenRecorder.shared()
        
        // Start screen recording
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            screenRecorder?.startCapture { sampleBuffer, bufferType, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Process video frame
                Task {
                    await self.processVideoFrame(sampleBuffer, bufferType: bufferType, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                continuation.resume()
            }
        }
    }
    
    private func stopScreenTranslation() {
        screenRecorder?.stopCapture { error in
            if let error = error {
                print("Error stopping screen recording: \(error)")
            }
        }
        screenRecorder = nil
    }
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer, bufferType: RPSampleBufferType, sourceLanguage: Language, targetLanguage: Language) async {
        guard isTranslating && bufferType == .video else { return }
        
        do {
            // Extract image from video frame
            let image = try extractImage(from: sampleBuffer)
            
            // Use AI to detect text in image
            let detectedText = try await aiService.detectText(in: image)
            
            // Translate detected text
            let translation = try await translationService.translateText(
                detectedText,
                from: sourceLanguage,
                to: targetLanguage
            )
            
            let result = LiveTranslationResult(
                type: .screen,
                originalText: detectedText,
                translatedText: translation.text,
                confidence: translation.confidence,
                timestamp: Date(),
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            
            translationSubject.send(result)
            
        } catch {
            handleTranslationError(error)
        }
    }
    
    private func extractImage(from sampleBuffer: CMSampleBuffer) throws -> UIImage {
        // Convert CMSampleBuffer to UIImage
        // This is a simplified implementation
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw LiveTranslationError.failedToExtractImage
        }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw LiveTranslationError.failedToExtractImage
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Picture in Picture Translation
    private func startPictureInPictureTranslation(sourceLanguage: Language, targetLanguage: Language) async throws {
        // Create picture in picture controller
        let playerViewController = AVPlayerViewController()
        let pipController = AVPictureInPictureController(playerLayer: playerViewController.player?.currentItem)
        
        guard pipController != nil else {
            throw LiveTranslationError.pictureInPictureNotAvailable
        }
        
        // Create overlay view for translation
        let overlayView = createTranslationOverlay()
        
        // Start picture in picture
        pipController?.start()
        
        // Setup audio capture for translation
        try await startAudioTranslation(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        
        // Display translation in overlay
        setupOverlayTranslation(overlayView, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
    }
    
    private func stopPictureInPictureTranslation() {
        stopAudioTranslation()
        // Additional cleanup for picture in picture
    }
    
    private func createTranslationOverlay() -> UIView {
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        overlayView.layer.cornerRadius = 12
        
        let titleLabel = UILabel()
        titleLabel.text = "Live Translation"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        
        let translationLabel = UILabel()
        translationLabel.text = ""
        translationLabel.textColor = .white
        translationLabel.font = .systemFont(ofSize: 14)
        translationLabel.numberOfLines = 0
        
        [titleLabel, translationLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            overlayView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -12),
            
            translationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            translationLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 12),
            translationLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -12),
            translationLabel.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor, constant: -8)
        ])
        
        return overlayView
    }
    
    private func setupOverlayTranslation(_ overlayView: UIView, sourceLanguage: Language, targetLanguage: Language) {
        translationPublisher
            .receive(on: DispatchQueue.main)
            .sink { result in
                if let translationLabel = overlayView.subviews.last as? UILabel {
                    translationLabel.text = result.translatedText
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    private func setupAudioSession() {
        do {
            audioSession = AVAudioSession.sharedInstance()
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupPermissions() {
        // Setup permission monitoring
    }
    
    private func handleTranslationError(_ error: Error) {
        stateSubject.send(.error(error))
        print("Translation error: \(error)")
    }
}

// MARK: - Live Translation Types
enum LiveTranslationMode {
    case audio
    case screen
    case pictureInPicture
}

enum LiveTranslationState {
    case idle
    case starting
    case active
    case paused
    case stopping
    case error(Error)
    
    var isActive: Bool {
        switch self {
        case .active:
            return true
        default:
            return false
        }
    }
}

struct LiveTranslationResult {
    let type: LiveTranslationMode
    let originalText: String
    let translatedText: String
    let confidence: Double
    let timestamp: Date
    let sourceLanguage: Language
    let targetLanguage: Language
}

enum LiveTranslationError: LocalizedError {
    case alreadyRecording
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case screenRecordingNotAvailable
    case pictureInPictureNotAvailable
    case failedToExtractImage
    case translationServiceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Already recording"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        case .speechRecognitionPermissionDenied:
            return "Speech recognition permission denied"
        case .screenRecordingNotAvailable:
            return "Screen recording not available"
        case .pictureInPictureNotAvailable:
            return "Picture in picture not available"
        case .failedToExtractImage:
            return "Failed to extract image from video frame"
        case .translationServiceUnavailable:
            return "Translation service unavailable"
        }
    }
}

// MARK: - Extensions
extension LiveTranslationService {
    private var audioSession: AVAudioSession {
        return AVAudioSession.sharedInstance()
    }
}
