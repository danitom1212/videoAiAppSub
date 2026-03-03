import UIKit
import AVFoundation
import AVKit
import Combine
import SwiftUI

// MARK: - Modern Video Player Controller
class VideoPlayerViewController: UIViewController {
    
    // MARK: - UI Components
    private var videoPlayerView: AVPlayerView!
    private var subtitleOverlayView: SubtitleOverlayView!
    private var controlsView: VideoControlsView!
    private var languageSelectionButton: UIButton!
    private var importVideoButton: UIButton!
    private var translateButton: UIButton!
    private var universalTranslateButton: UIButton!
    private var progressIndicator: UIProgressView!
    private var statusLabel: UILabel!
    private var gestureView: UIView!
    
    // MARK: - Modern UI Elements
    private var blurEffectView: UIVisualEffectView!
    private var containerView: UIView!
    private var topControlsView: UIView!
    private var bottomControlsView: UIView!
    private var sidePanelView: UIView!
    private var miniPlayerView: UIView!
    
    // MARK: - Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var currentVideoURL: URL?
    private var transcriptionService: TranscriptionService!
    private var translationService: TranslationService!
    private var subtitleManager: SubtitleManager!
    private var aiService: AIService!
    private var screenTranslationService: ScreenTranslationService!
    private var liveTranslationService: LiveTranslationService!
    
    // Dependency Injection
    private let auth: AuthProviding = AppContainer.shared.auth
    private let analytics: AnalyticsStore = AppContainer.shared.analytics
    private let networkManager: NetworkManager = AppContainer.shared.networkManager
    private let securityManager: SecurityManager = AppContainer.shared.securityManager
    
    // State Management
    private var selectedSourceLanguage: Language = Language.language(for: "en")!
    private var selectedTargetLanguage: Language = Language.language(for: "es")!
    private var isTranscribing = false
    private var isTranslating = false
    private var isUniversalTranslating = false
    private var isPlaying = false
    private var controlsVisible = true
    private var isFullscreen = false
    private var isMiniPlayer = false
    
    // Combine Publishers
    private var cancellables = Set<AnyCancellable>()
    private var playbackStateSubject = CurrentValueSubject<PlaybackState, Never>(.stopped)
    private var processingStateSubject = CurrentValueSubject<ProcessingState, Never>(.idle)
    private var errorStateSubject = PassthroughSubject<Error, Never>()
    
    // Publishers
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        playbackStateSubject.eraseToAnyPublisher()
    }
    
    var processingStatePublisher: AnyPublisher<ProcessingState, Never> {
        processingStateSubject.eraseToAnyPublisher()
    }
    
    var errorStatePublisher: AnyPublisher<Error, Never> {
        errorStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupModernUI()
        setupServices()
        setupCombineBindings()
        setupGestures()
        setupNotifications()
        setupNavigation()
        setupAccessibility()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        translationService.refreshSettings()
        setupAppearance()
        startPerformanceMonitoring()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cleanupResources()
        removeTimeObserver()
    }
    
    // MARK: - Modern UI Setup
    private func setupModernUI() {
        view.backgroundColor = .systemBackground
        
        setupContainerView()
        setupVideoPlayerView()
        setupBlurEffects()
        setupTopControls()
        setupBottomControls()
        setupSidePanel()
        setupProgressIndicator()
        setupStatusLabel()
        setupGestureView()
        setupMiniPlayer()
        
        layoutConstraints()
        applyModernStyling()
        setupAnimations()
    }
    
    private func setupContainerView() {
        containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .black
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true
        view.addSubview(containerView)
    }
    
    private func setupVideoPlayerView() {
        videoPlayerView = AVPlayerView()
        videoPlayerView.translatesAutoresizingMaskIntoConstraints = false
        videoPlayerView.backgroundColor = .black
        videoPlayerView.layer.cornerRadius = 8
        containerView.addSubview(videoPlayerView)
    }
    
    private func setupBlurEffects() {
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.alpha = 0.0
        containerView.addSubview(blurEffectView)
    }
    
    private func setupTopControls() {
        topControlsView = UIView()
        topControlsView.translatesAutoresizingMaskIntoConstraints = false
        topControlsView.backgroundColor = .clear
        
        // Back button
        let backButton = createModernButton(
            title: nil,
            imageName: "chevron.left",
            backgroundColor: .systemGray5,
            tintColor: .label
        )
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "Video Translator"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        
        // More options button
        let moreButton = createModernButton(
            title: nil,
            imageName: "ellipsis",
            backgroundColor: .systemGray5,
            tintColor: .label
        )
        moreButton.addTarget(self, action: #selector(moreButtonTapped), for: .touchUpInside)
        
        [backButton, titleLabel, moreButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            topControlsView.addSubview($0)
        }
        
        containerView.addSubview(topControlsView)
        
        // Constraints
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: topControlsView.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: topControlsView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.centerXAnchor.constraint(equalTo: topControlsView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topControlsView.centerYAnchor),
            
            moreButton.trailingAnchor.constraint(equalTo: topControlsView.trailingAnchor, constant: -16),
            moreButton.centerYAnchor.constraint(equalTo: topControlsView.centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: 44),
            moreButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupBottomControls() {
        bottomControlsView = UIView()
        bottomControlsView.translatesAutoresizingMaskIntoConstraints = false
        bottomControlsView.backgroundColor = .clear
        
        // Import button
        importVideoButton = createModernButton(
            title: "Import Video",
            imageName: "square.and.arrow.down",
            backgroundColor: .systemBlue,
            tintColor: .white
        )
        importVideoButton.addTarget(self, action: #selector(importVideoButtonTapped), for: .touchUpInside)
        
        // Translate button
        translateButton = createModernButton(
            title: "Translate",
            imageName: "globe",
            backgroundColor: .systemGreen,
            tintColor: .white
        )
        translateButton.addTarget(self, action: #selector(translateButtonTapped), for: .touchUpInside)
        
        // Language selection button
        languageSelectionButton = createModernButton(
            title: "\(selectedSourceLanguage.code) → \(selectedTargetLanguage.code)",
            imageName: "arrow.left.arrow.right",
            backgroundColor: .systemOrange,
            tintColor: .white
        )
        languageSelectionButton.addTarget(self, action: #selector(languageSelectionButtonTapped), for: .touchUpInside)
        
        // Universal translate button
        universalTranslateButton = createModernButton(
            title: "🌍 Translate Screen",
            imageName: "globe.2",
            backgroundColor: .systemPurple,
            tintColor: .white
        )
        universalTranslateButton.addTarget(self, action: #selector(universalTranslateButtonTapped), for: .touchUpInside)
        
        [importVideoButton, translateButton, languageSelectionButton, universalTranslateButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            bottomControlsView.addSubview($0)
        }
        
        containerView.addSubview(bottomControlsView)
        
        // Constraints
        NSLayoutConstraint.activate([
            importVideoButton.leadingAnchor.constraint(equalTo: bottomControlsView.leadingAnchor, constant: 8),
            importVideoButton.bottomAnchor.constraint(equalTo: bottomControlsView.bottomAnchor, constant: -16),
            importVideoButton.widthAnchor.constraint(equalToConstant: 100),
            
            translateButton.leadingAnchor.constraint(equalTo: importVideoButton.trailingAnchor, constant: 8),
            translateButton.bottomAnchor.constraint(equalTo: bottomControlsView.bottomAnchor, constant: -16),
            translateButton.widthAnchor.constraint(equalToConstant: 80),
            
            languageSelectionButton.leadingAnchor.constraint(equalTo: translateButton.trailingAnchor, constant: 8),
            languageSelectionButton.bottomAnchor.constraint(equalTo: bottomControlsView.bottomAnchor, constant: -16),
            languageSelectionButton.widthAnchor.constraint(equalToConstant: 100),
            
            universalTranslateButton.trailingAnchor.constraint(equalTo: bottomControlsView.trailingAnchor, constant: -8),
            universalTranslateButton.bottomAnchor.constraint(equalTo: bottomControlsView.bottomAnchor, constant: -16),
            universalTranslateButton.widthAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    private func setupSidePanel() {
        sidePanelView = UIView()
        sidePanelView.translatesAutoresizingMaskIntoConstraints = false
        sidePanelView.backgroundColor = .systemBackground
        sidePanelView.layer.cornerRadius = 12
        sidePanelView.layer.shadowColor = UIColor.black.cgColor
        sidePanelView.layer.shadowOffset = CGSize(width: 0, height: 2)
        sidePanelView.layer.shadowRadius = 8
        sidePanelView.layer.shadowOpacity = 0.1
        sidePanelView.alpha = 0.0
        sidePanelView.transform = CGAffineTransform(translationX: 300, y: 0)
        
        // Settings button
        let settingsButton = createModernButton(
            title: "Settings",
            imageName: "gearshape",
            backgroundColor: .systemGray5,
            tintColor: .label
        )
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        
        // Analytics button
        let analyticsButton = createModernButton(
            title: "Analytics",
            imageName: "chart.bar",
            backgroundColor: .systemGray5,
            tintColor: .label
        )
        analyticsButton.addTarget(self, action: #selector(analyticsTapped), for: .touchUpInside)
        
        // Admin button
        let adminButton = createModernButton(
            title: "Admin",
            imageName: "person.crop.circle",
            backgroundColor: .systemPurple,
            tintColor: .white
        )
        adminButton.addTarget(self, action: #selector(adminTapped), for: .touchUpInside)
        
        [settingsButton, analyticsButton, adminButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            sidePanelView.addSubview($0)
        }
        
        view.addSubview(sidePanelView)
        
        // Constraints
        NSLayoutConstraint.activate([
            settingsButton.topAnchor.constraint(equalTo: sidePanelView.topAnchor, constant: 100),
            settingsButton.leadingAnchor.constraint(equalTo: sidePanelView.leadingAnchor, constant: 16),
            settingsButton.trailingAnchor.constraint(equalTo: sidePanelView.trailingAnchor, constant: -16),
            settingsButton.heightAnchor.constraint(equalToConstant: 50),
            
            analyticsButton.topAnchor.constraint(equalTo: settingsButton.bottomAnchor, constant: 12),
            analyticsButton.leadingAnchor.constraint(equalTo: sidePanelView.leadingAnchor, constant: 16),
            analyticsButton.trailingAnchor.constraint(equalTo: sidePanelView.trailingAnchor, constant: -16),
            analyticsButton.heightAnchor.constraint(equalToConstant: 50),
            
            adminButton.topAnchor.constraint(equalTo: analyticsButton.bottomAnchor, constant: 12),
            adminButton.leadingAnchor.constraint(equalTo: sidePanelView.leadingAnchor, constant: 16),
            adminButton.trailingAnchor.constraint(equalTo: sidePanelView.trailingAnchor, constant: -16),
            adminButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupProgressIndicator() {
        progressIndicator = UIProgressView()
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.progressTintColor = .systemBlue
        progressIndicator.trackTintColor = .systemGray5
        progressIndicator.layer.cornerRadius = 2
        progressIndicator.alpha = 0.0
        containerView.addSubview(progressIndicator)
    }
    
    private func setupStatusLabel() {
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Ready"
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.alpha = 0.0
        containerView.addSubview(statusLabel)
    }
    
    private func setupGestureView() {
        gestureView = UIView()
        gestureView.translatesAutoresizingMaskIntoConstraints = false
        gestureView.backgroundColor = .clear
        containerView.addSubview(gestureView)
    }
    
    private func setupMiniPlayer() {
        miniPlayerView = UIView()
        miniPlayerView.translatesAutoresizingMaskIntoConstraints = false
        miniPlayerView.backgroundColor = .systemBackground
        miniPlayerView.layer.cornerRadius = 12
        miniPlayerView.layer.shadowColor = UIColor.black.cgColor
        miniPlayerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        miniPlayerView.layer.shadowRadius = 8
        miniPlayerView.layer.shadowOpacity = 0.2
        miniPlayerView.alpha = 0.0
        miniPlayerView.transform = CGAffineTransform(translationX: 0, y: 300)
        
        view.addSubview(miniPlayerView)
    }
    
    // MARK: - Helper Methods
    private func createModernButton(title: String?, imageName: String?, backgroundColor: UIColor, tintColor: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = backgroundColor
        button.tintColor = tintColor
        button.layer.cornerRadius = 12
        button.layer.shadowColor = backgroundColor.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.2
        
        if let title = title {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        }
        
        if let imageName = imageName {
            button.setImage(UIImage(systemName: imageName), for: .normal)
        }
        
        return button
    }
    
    private func layoutConstraints() {
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            
            // Video player view
            videoPlayerView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            videoPlayerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            videoPlayerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            videoPlayerView.heightAnchor.constraint(equalTo: videoPlayerView.widthAnchor, multiplier: 9/16),
            
            // Blur effect view
            blurEffectView.topAnchor.constraint(equalTo: videoPlayerView.topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: videoPlayerView.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: videoPlayerView.trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: videoPlayerView.bottomAnchor),
            
            // Top controls
            topControlsView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            topControlsView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            topControlsView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            topControlsView.heightAnchor.constraint(equalToConstant: 60),
            
            // Bottom controls
            bottomControlsView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            bottomControlsView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            bottomControlsView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            bottomControlsView.heightAnchor.constraint(equalToConstant: 80),
            
            // Progress indicator
            progressIndicator.topAnchor.constraint(equalTo: videoPlayerView.bottomAnchor, constant: 8),
            progressIndicator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            progressIndicator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Gesture view
            gestureView.topAnchor.constraint(equalTo: videoPlayerView.topAnchor),
            gestureView.leadingAnchor.constraint(equalTo: videoPlayerView.leadingAnchor),
            gestureView.trailingAnchor.constraint(equalTo: videoPlayerView.trailingAnchor),
            gestureView.bottomAnchor.constraint(equalTo: videoPlayerView.bottomAnchor),
            
            // Side panel
            sidePanelView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sidePanelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sidePanelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidePanelView.widthAnchor.constraint(equalToConstant: 300),
            
            // Mini player
            miniPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            miniPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            miniPlayerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            miniPlayerView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    private func applyModernStyling() {
        // Apply modern styling to all components
        view.layer.backgroundColor = UIColor.systemBackground.cgColor
        
        // Apply corner radius and shadows
        [importVideoButton, translateButton, languageSelectionButton].forEach {
            $0.layer.cornerRadius = 12
            $0.layer.shadowColor = $0.backgroundColor?.cgColor ?? UIColor.clear.cgColor
            $0.layer.shadowOffset = CGSize(width: 0, height: 2)
            $0.layer.shadowRadius = 4
            $0.layer.shadowOpacity = 0.2
        }
    }
    
    private func setupAnimations() {
        // Setup initial animations
        topControlsView.alpha = 0.0
        bottomControlsView.alpha = 0.0
    }
    
    private func setupAppearance() {
        // Setup appearance based on user preferences
        overrideUserInterfaceStyle = .unspecified
    }
    
    private func setupAccessibility() {
        // Setup accessibility for all components
        videoPlayerView.isAccessibilityElement = true
        videoPlayerView.accessibilityLabel = "Video player"
        
        importVideoButton.isAccessibilityElement = true
        importVideoButton.accessibilityLabel = "Import video"
        importVideoButton.accessibilityHint = "Import a video file for translation"
        
        translateButton.isAccessibilityElement = true
        translateButton.accessibilityLabel = "Translate video"
        translateButton.accessibilityHint = "Start translating the current video"
        
        languageSelectionButton.isAccessibilityElement = true
        languageSelectionButton.accessibilityLabel = "Language selection"
        languageSelectionButton.accessibilityHint = "Select source and target languages"
    }
        view.backgroundColor = .black
        
        // Setup video player view
        videoPlayerView = AVPlayerView()
        videoPlayerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoPlayerView)
        
        // Setup subtitle overlay
        subtitleOverlayView = SubtitleOverlayView()
        subtitleOverlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleOverlayView)
        
        // Setup controls
        controlsView = VideoControlsView()
        controlsView.translatesAutoresizingMaskIntoConstraints = false
        controlsView.delegate = self
        view.addSubview(controlsView)
        
        // Setup buttons
        setupButtons()
        
        setupConstraints()
    }

    private func setupNavigation() {
        title = "Video"

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(logoutTapped))

        let settings = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(settingsTapped))

        var rightItems: [UIBarButtonItem] = [settings]
        if auth.currentUser?.role == .admin {
            let admin = UIBarButtonItem(title: "Admin", style: .plain, target: self, action: #selector(adminTapped))
            rightItems.insert(admin, at: 0)
        }
        navigationItem.rightBarButtonItems = rightItems
    }
    
    private func setupButtons() {
        // Language selection button
        languageSelectionButton = UIButton(type: .system)
        languageSelectionButton.setTitle("🌐 Language", for: .normal)
        languageSelectionButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        languageSelectionButton.setTitleColor(.white, for: .normal)
        languageSelectionButton.layer.cornerRadius = 8
        languageSelectionButton.translatesAutoresizingMaskIntoConstraints = false
        languageSelectionButton.addTarget(self, action: #selector(languageButtonTapped), for: .touchUpInside)
        view.addSubview(languageSelectionButton)
        
        // Import video button
        importVideoButton = UIButton(type: .system)
        importVideoButton.setTitle("📁 Import Video", for: .normal)
        importVideoButton.backgroundColor = UIColor.systemBlue
        importVideoButton.setTitleColor(.white, for: .normal)
        importVideoButton.layer.cornerRadius = 8
        importVideoButton.translatesAutoresizingMaskIntoConstraints = false
        importVideoButton.addTarget(self, action: #selector(importVideoButtonTapped), for: .touchUpInside)
        view.addSubview(importVideoButton)
        
        // Translate button
        translateButton = UIButton(type: .system)
        translateButton.setTitle("🔄 Translate", for: .normal)
        translateButton.backgroundColor = UIColor.systemGreen
        translateButton.setTitleColor(.white, for: .normal)
        translateButton.layer.cornerRadius = 8
        translateButton.translatesAutoresizingMaskIntoConstraints = false
        translateButton.addTarget(self, action: #selector(translateButtonTapped), for: .touchUpInside)
        view.addSubview(translateButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Video player view
            videoPlayerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            videoPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoPlayerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
            
            // Subtitle overlay
            subtitleOverlayView.topAnchor.constraint(equalTo: videoPlayerView.topAnchor),
            subtitleOverlayView.leadingAnchor.constraint(equalTo: videoPlayerView.leadingAnchor),
            subtitleOverlayView.trailingAnchor.constraint(equalTo: videoPlayerView.trailingAnchor),
            subtitleOverlayView.bottomAnchor.constraint(equalTo: videoPlayerView.bottomAnchor),
            
            // Controls view
            controlsView.topAnchor.constraint(equalTo: videoPlayerView.bottomAnchor),
            controlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsView.heightAnchor.constraint(equalToConstant: 80),
            
            // Language button
            languageSelectionButton.topAnchor.constraint(equalTo: controlsView.bottomAnchor, constant: 10),
            languageSelectionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            languageSelectionButton.widthAnchor.constraint(equalToConstant: 120),
            languageSelectionButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Import button
            importVideoButton.topAnchor.constraint(equalTo: controlsView.bottomAnchor, constant: 10),
            importVideoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            importVideoButton.widthAnchor.constraint(equalToConstant: 140),
            importVideoButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Translate button
            translateButton.topAnchor.constraint(equalTo: controlsView.bottomAnchor, constant: 10),
            translateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            translateButton.widthAnchor.constraint(equalToConstant: 120),
            translateButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupServices() {
        transcriptionService = AppContainer.shared.transcriptionService
        translationService = AppContainer.shared.translationService
        subtitleManager = AppContainer.shared.subtitleManager
        aiService = AppContainer.shared.aiService
        screenTranslationService = AppContainer.shared.screenTranslationService
        liveTranslationService = AppContainer.shared.liveTranslationService
        
        transcriptionService.delegate = self
        translationService.delegate = self
        subtitleManager.delegate = self
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    // MARK: - Video Loading
    private func loadVideo(url: URL) {
        currentVideoURL = url
        
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        videoPlayerView.player = player
        
        setupTimeObserver()
        
        // Start transcription when video is loaded
        transcriptionService.transcribeAudio(from: url)
    }
    
    // MARK: - Time Observer
    private func setupTimeObserver() {
        guard let player = player else { return }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: 1000)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateSubtitles(for: time)
        }
    }
    
    private func removeTimeObserver() {
        guard let player = player, let timeObserver = timeObserver else { return }
        player.removeTimeObserver(timeObserver)
        self.timeObserver = nil
    }
    
    private func updateSubtitles(for time: CMTime) {
        let currentTime = time.seconds
        subtitleManager.updateCurrentTime(currentTime)
    }
    
    // MARK: - Actions
    @objc private func languageButtonTapped() {
        let languageVC = LanguageSelectionViewController()
        languageVC.delegate = self
        let navController = UINavigationController(rootViewController: languageVC)
        present(navController, animated: true)
    }
    
    @objc private func importVideoButtonTapped() {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.movie"], in: .open)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }
    
    @objc private func translateButtonTapped() {
        let subtitles = subtitleManager.currentSubtitles
        guard !subtitles.isEmpty else {
            showAlert(title: "No Subtitles", message: "Please wait for transcription to complete or import a video first.")
            return
        }
        
        translationService.translateSubtitles(subtitles)
    }
    
    @objc private func universalTranslateButtonTapped() {
        guard !isUniversalTranslating else {
            stopUniversalTranslation()
            return
        }
        
        startUniversalTranslation()
    }
    
    private func startUniversalTranslation() {
        isUniversalTranslating = true
        universalTranslateButton.setTitle("⏹️ Stop Translation", for: .normal)
        universalTranslateButton.backgroundColor = .systemRed
        
        // Initialize services if needed
        if screenTranslationService == nil {
            screenTranslationService = AppContainer.shared.screenTranslationService
        }
        
        Task {
            do {
                try await screenTranslationService.startUniversalTranslation(
                    sourceLanguage: selectedSourceLanguage,
                    targetLanguage: selectedTargetLanguage
                )
                
                showAlert(title: "🌍 Universal Translation Started", message: "Translating everything on your screen!")
                
            } catch {
                showAlert(title: "Translation Error", message: "Failed to start universal translation: \(error.localizedDescription)")
                stopUniversalTranslation()
            }
        }
    }
    
    private func stopUniversalTranslation() {
        isUniversalTranslating = false
        universalTranslateButton.setTitle("🌍 Translate Screen", for: .normal)
        universalTranslateButton.backgroundColor = .systemPurple
        
        screenTranslationService?.stopUniversalTranslation()
        
        showAlert(title: "Translation Stopped", message: "Universal translation has been stopped.")
    }

    @objc private func settingsTapped() {
        let vc = SettingsViewController()
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    @objc private func adminTapped() {
        let vc = AdminDashboardViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func logoutTapped() {
        let email = auth.currentUser?.email
        analytics.track(AnalyticsEvent(type: .signOut, userEmail: email))
        auth.signOut()
    }
    
    @objc private func playerItemDidReachEnd() {
        player?.seek(to: .zero)
        player?.pause()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - VideoControlsDelegate
extension VideoPlayerViewController: VideoControlsDelegate {
    func playButtonTapped() {
        if player?.rate == 0 {
            player?.play()
        } else {
            player?.pause()
        }
    }
    
    func seekToTime(_ time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        player?.seek(to: cmTime)
    }
    
    func volumeChanged(_ volume: Float) {
        player?.volume = volume
    }
}

// MARK: - UIDocumentPickerDelegate
extension VideoPlayerViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let videoURL = urls.first else { return }
        loadVideo(url: videoURL)
    }
}

// MARK: - TranscriptionServiceDelegate
extension VideoPlayerViewController: TranscriptionServiceDelegate {
    func transcriptionDidStart() {
        DispatchQueue.main.async {
            self.translateButton.isEnabled = false
            self.translateButton.setTitle("⏳ Transcribing...", for: .normal)
        }
    }
    
    func transcriptionDidComplete(with subtitles: [Subtitle]) {
        DispatchQueue.main.async {
            self.subtitleManager.setSubtitles(subtitles)
            self.translateButton.isEnabled = true
            self.translateButton.setTitle("🔄 Translate", for: .normal)
        }
    }
    
    func transcriptionDidFail(with error: Error) {
        DispatchQueue.main.async {
            self.translateButton.isEnabled = true
            self.translateButton.setTitle("🔄 Translate", for: .normal)
            self.showAlert(title: "Transcription Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - TranslationServiceDelegate
extension VideoPlayerViewController: TranslationServiceDelegate {
    func translationDidStart() {
        DispatchQueue.main.async {
            self.translateButton.setTitle("⏳ Translating...", for: .normal)
            self.translateButton.isEnabled = false
        }
    }
    
    func translationDidComplete(with translatedSubtitles: [Subtitle]) {
        DispatchQueue.main.async {
            self.subtitleManager.setTranslatedSubtitles(translatedSubtitles)
            self.translateButton.setTitle("✅ Translated", for: .normal)
            self.translateButton.isEnabled = true

            let email = self.auth.currentUser?.email
            self.analytics.track(AnalyticsEvent(type: .translation, userEmail: email, sourceLanguage: self.selectedSourceLanguage.code, targetLanguage: self.selectedTargetLanguage.code, provider: "openai_or_passthrough"))
            
            // Reset button after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.translateButton.setTitle("🔄 Translate", for: .normal)
            }
        }
    }
    
    func translationDidFail(with error: Error) {
        DispatchQueue.main.async {
            self.translateButton.setTitle("🔄 Translate", for: .normal)
            self.translateButton.isEnabled = true
            self.showAlert(title: "Translation Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - SubtitleManagerDelegate
extension VideoPlayerViewController: SubtitleManagerDelegate {
    func subtitleDidUpdate(_ subtitle: Subtitle?) {
        DispatchQueue.main.async {
            self.subtitleOverlayView.updateSubtitle(subtitle)
        }
    }
}

// MARK: - LanguageSelectionDelegate
extension VideoPlayerViewController: LanguageSelectionDelegate {
    func didSelectLanguage(sourceLanguage: Language, targetLanguage: Language) {
        selectedSourceLanguage = sourceLanguage
        selectedTargetLanguage = targetLanguage
        translationService.setLanguages(source: sourceLanguage, target: targetLanguage)
        subtitleManager.setTargetLanguage(targetLanguage)
    }
}
