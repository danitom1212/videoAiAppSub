import UIKit
import AVFoundation
import AVKit

class VideoPlayerViewController: UIViewController {
    
    // MARK: - UI Components
    private var videoPlayerView: AVPlayerView!
    private var subtitleOverlayView: SubtitleOverlayView!
    private var controlsView: VideoControlsView!
    private var languageSelectionButton: UIButton!
    private var importVideoButton: UIButton!
    private var translateButton: UIButton!
    
    // MARK: - Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var currentVideoURL: URL?
    private var transcriptionService: TranscriptionService!
    private var translationService: TranslationService!
    private var subtitleManager: SubtitleManager!

    private let auth: AuthProviding = AppContainer.shared.auth
    private let analytics: AnalyticsStore = AppContainer.shared.analytics

    private var selectedSourceLanguage: Language = Language.language(for: "en")!
    private var selectedTargetLanguage: Language = Language.language(for: "es")!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupServices()
        setupNotifications()
        setupNavigation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        translationService.refreshSettings()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeTimeObserver()
    }
    
    // MARK: - Setup
    private func setupUI() {
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
        transcriptionService = TranscriptionService()
        transcriptionService.delegate = self
        
        translationService = TranslationService()
        translationService.delegate = self
        
        subtitleManager = SubtitleManager()
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
