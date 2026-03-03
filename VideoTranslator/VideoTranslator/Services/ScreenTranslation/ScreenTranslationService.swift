import Foundation
import UIKit
import Combine
import Vision
import CoreGraphics

// MARK: - Screen Translation Service (Advanced)
class ScreenTranslationService {
    // MARK: - Properties
    private let aiService: AIService
    private let translationService: TranslationService
    private var screenReader: ScreenReader?
    private var overlayWindow: OverlayWindow?
    private var isTranslating = false
    
    // MARK: - Publishers
    private var translationSubject = PassthroughSubject<ScreenTranslationResult, Never>()
    var translationPublisher: AnyPublisher<ScreenTranslationResult, Never> {
        translationSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init(aiService: AIService, translationService: TranslationService) {
        self.aiService = aiService
        self.translationService = translationService
        setupScreenReader()
        setupOverlayWindow()
    }
    
    // MARK: - Public Methods
    
    func startUniversalTranslation(sourceLanguage: Language, targetLanguage: Language) async throws {
        guard !isTranslating else {
            throw ScreenTranslationError.alreadyTranslating
        }
        
        isTranslating = true
        
        // Start universal screen monitoring
        try await startUniversalScreenMonitoring(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        
        // Show overlay window
        showTranslationOverlay()
    }
    
    func stopUniversalTranslation() {
        isTranslating = false
        screenReader?.stopMonitoring()
        hideTranslationOverlay()
    }
    
    // MARK: - Universal Screen Monitoring
    
    private func startUniversalScreenMonitoring(sourceLanguage: Language, targetLanguage: Language) async throws {
        // Method 1: Accessibility API (if available)
        if canUseAccessibilityAPI() {
            try await startAccessibilityMonitoring(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        }
        
        // Method 2: Screen Capture + OCR
        try await startScreenCaptureMonitoring(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        
        // Method 3: System Event Monitoring
        startSystemEventMonitoring(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
    }
    
    // MARK: - Accessibility API Method
    
    private func canUseAccessibilityAPI() -> Bool {
        // Check if accessibility permissions are granted
        return AXIsProcessTrusted() ?? false
    }
    
    private func startAccessibilityMonitoring(sourceLanguage: Language, targetLanguage: Language) async throws {
        guard canUseAccessibilityAPI() else {
            print("Accessibility API not available")
            return
        }
        
        screenReader = ScreenReader()
        screenReader?.startMonitoring { [weak self] elements in
            Task {
                await self?.processAccessibilityElements(elements, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            }
        }
    }
    
    private func processAccessibilityElements(_ elements: [AccessibilityElement], sourceLanguage: Language, targetLanguage: Language) async {
        for element in elements {
            guard let text = element.text, !text.isEmpty else { continue }
            
            do {
                let translation = try await translationService.translateText(
                    text,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                
                let result = ScreenTranslationResult(
                    type: .accessibility,
                    originalText: text,
                    translatedText: translation.text,
                    position: element.frame,
                    confidence: translation.confidence,
                    timestamp: Date(),
                    elementType: element.type
                )
                
                translationSubject.send(result)
                updateOverlay(with: result)
                
            } catch {
                print("Translation error: \(error)")
            }
        }
    }
    
    // MARK: - Screen Capture + OCR Method
    
    private func startScreenCaptureMonitoring(sourceLanguage: Language, targetLanguage: Language) async throws {
        // Create screen capture timer
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task {
                await self?.captureAndTranslateScreen(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            }
        }
    }
    
    private func captureAndTranslateScreen(sourceLanguage: Language, targetLanguage: Language) async {
        guard isTranslating else { return }
        
        do {
            // Capture screen
            let screenshot = try captureScreen()
            
            // Extract text using Vision framework
            let textElements = try await extractTextFromImage(screenshot)
            
            // Translate each text element
            for element in textElements {
                let translation = try await translationService.translateText(
                    element.text,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                
                let result = ScreenTranslationResult(
                    type: .ocr,
                    originalText: element.text,
                    translatedText: translation.text,
                    position: element.frame,
                    confidence: translation.confidence,
                    timestamp: Date(),
                    elementType: .text
                )
                
                translationSubject.send(result)
                updateOverlay(with: result)
            }
            
        } catch {
            print("Screen capture error: \(error)")
        }
    }
    
    private func captureScreen() throws -> UIImage {
        // Method 1: UIScreen.main.capture (if available)
        if #available(iOS 16.0, *) {
            let window = UIApplication.shared.windows.first { $0.isKeyWindow }
            let renderer = UIGraphicsImageRenderer(bounds: window?.bounds ?? UIScreen.main.bounds)
            return renderer.image { _ in
                window?.drawHierarchy(in: window?.bounds ?? UIScreen.main.bounds, afterScreenUpdates: true)
            }
        }
        
        // Method 2: UIGraphicsScreenCapture (if available)
        if #available(iOS 10.0, *) {
            let window = UIApplication.shared.windows.first { $0.isKeyWindow }
            UIGraphicsBeginImageContextWithOptions(window?.bounds.size ?? CGSize.zero, false, UIScreen.main.scale)
            window?.drawHierarchy(in: window?.bounds ?? UIScreen.main.bounds, afterScreenUpdates: true)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image ?? UIImage()
        }
        
        throw ScreenTranslationError.screenCaptureFailed
    }
    
    private func extractTextFromImage(_ image: UIImage) async throws -> [TextElement] {
        let request = VNRecognizeTextRequest { request, error in
            // Handle completion
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        try handler.perform([request])
        
        // Extract text results
        var textElements: [TextElement] = []
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return textElements
        }
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let textElement = TextElement(
                text: topCandidate.string,
                frame: observation.boundingBox,
                confidence: Double(topCandidate.confidence)
            )
            
            textElements.append(textElement)
        }
        
        return textElements
    }
    
    // MARK: - System Event Monitoring
    
    private func startSystemEventMonitoring(sourceLanguage: Language, targetLanguage: Language) {
        // Monitor system events like notifications, alerts, etc.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleSystemEvent(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            }
        }
    }
    
    private func handleSystemEvent(sourceLanguage: Language, targetLanguage: Language) async {
        // Handle system events like notifications, alerts, etc.
        // This could capture system dialogs, notifications, etc.
    }
    
    // MARK: - Overlay Management
    
    private func setupOverlayWindow() {
        overlayWindow = OverlayWindow()
        overlayWindow?.isHidden = true
    }
    
    private func showTranslationOverlay() {
        overlayWindow?.isHidden = false
        overlayWindow?.makeKeyAndVisible()
    }
    
    private func hideTranslationOverlay() {
        overlayWindow?.isHidden = true
    }
    
    private func updateOverlay(with result: ScreenTranslationResult) {
        DispatchQueue.main.async {
            self.overlayWindow?.addTranslation(result)
        }
    }
    
    // MARK: - Screen Reader Setup
    
    private func setupScreenReader() {
        // Initialize screen reader for accessibility monitoring
    }
}

// MARK: - Screen Reader
class ScreenReader {
    private var monitoringTimer: Timer?
    private var elementHandler: (([AccessibilityElement]) -> Void)?
    
    func startMonitoring(handler: @escaping ([AccessibilityElement]) -> Void) {
        self.elementHandler = handler
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.scanScreen()
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func scanScreen() {
        var elements: [AccessibilityElement] = []
        
        // Scan for accessibility elements on screen
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            scanWindow(window, elements: &elements)
        }
        
        elementHandler?(elements)
    }
    
    private func scanWindow(_ view: UIView, elements: inout [AccessibilityElement]) {
        // Check if view has accessibility text
        if let accessibilityLabel = view.accessibilityLabel, !accessibilityLabel.isEmpty {
            let element = AccessibilityElement(
                text: accessibilityLabel,
                frame: view.frame,
                type: .accessibility
            )
            elements.append(element)
        }
        
        // Recursively scan subviews
        for subview in view.subviews {
            scanWindow(subview, elements: &elements)
        }
    }
}

// MARK: - Overlay Window
class OverlayWindow: UIWindow {
    private var translationViews: [TranslationView] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWindow()
    }
    
    private func setupWindow() {
        windowLevel = UIWindow.Level.alert + 1
        backgroundColor = UIColor.clear
        isUserInteractionEnabled = false
    }
    
    func addTranslation(_ result: ScreenTranslationResult) {
        let translationView = TranslationView(result: result)
        translationViews.append(translationView)
        addSubview(translationView)
        
        // Auto-remove after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            translationView.removeFromSuperview()
            self.translationViews.removeAll { $0 == translationView }
        }
    }
}

// MARK: - Translation View
class TranslationView: UIView {
    private let result: ScreenTranslationResult
    private let label: UILabel
    
    init(result: ScreenTranslationResult) {
        self.result = result
        self.label = UILabel()
        super.init(frame: result.frame)
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        layer.cornerRadius = 8
        
        label.text = result.translatedText
        label.textColor = .white
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
}

// MARK: - Supporting Types
struct AccessibilityElement {
    let text: String
    let frame: CGRect
    let type: ElementType
    
    enum ElementType {
        case accessibility
        case button
        case label
        case text
        case unknown
    }
}

struct TextElement {
    let text: String
    let frame: CGRect
    let confidence: Double
}

struct ScreenTranslationResult {
    let type: TranslationType
    let originalText: String
    let translatedText: String
    let position: CGRect
    let confidence: Double
    let timestamp: Date
    let elementType: AccessibilityElement.ElementType
    
    enum TranslationType {
        case accessibility
        case ocr
        case systemEvent
    }
}

enum ScreenTranslationError: LocalizedError {
    case alreadyTranslating
    case accessibilityNotAvailable
    case screenCaptureFailed
    case ocrFailed
    case translationFailed
    
    var errorDescription: String? {
        switch self {
        case .alreadyTranslating:
            return "Already translating"
        case .accessibilityNotAvailable:
            return "Accessibility API not available"
        case .screenCaptureFailed:
            return "Screen capture failed"
        case .ocrFailed:
            return "OCR failed"
        case .translationFailed:
            return "Translation failed"
        }
    }
}
