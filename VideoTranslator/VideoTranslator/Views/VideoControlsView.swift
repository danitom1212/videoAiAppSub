import UIKit
import AVKit

protocol VideoControlsDelegate: AnyObject {
    func playButtonTapped()
    func seekToTime(_ time: TimeInterval)
    func volumeChanged(_ volume: Float)
}

class VideoControlsView: UIView {
    
    // MARK: - UI Components
    private let playPauseButton: UIButton
    private let timeSlider: UISlider
    private let currentTimeLabel: UILabel
    private let totalTimeLabel: UILabel
    private let volumeSlider: UISlider
    private let volumeButton: UIButton
    private let fullscreenButton: UIButton
    
    // MARK: - Properties
    weak var delegate: VideoControlsDelegate?
    private var currentTime: TimeInterval = 0
    private var totalTime: TimeInterval = 0
    private var isPlaying: Bool = false
    private var isMuted: Bool = false
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        playPauseButton = UIButton(type: .system)
        timeSlider = UISlider()
        currentTimeLabel = UILabel()
        totalTimeLabel = UILabel()
        volumeSlider = UISlider()
        volumeButton = UIButton(type: .system)
        fullscreenButton = UIButton(type: .system)
        
        super.init(frame: frame)
        setupUI()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        // Play/Pause button
        playPauseButton.setTitle("▶️", for: .normal)
        playPauseButton.titleLabel?.font = .systemFont(ofSize: 20)
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Time labels
        currentTimeLabel.text = "00:00"
        currentTimeLabel.textColor = .white
        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        totalTimeLabel.text = "00:00"
        totalTimeLabel.textColor = .white
        totalTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        totalTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Time slider
        timeSlider.minimumValue = 0
        timeSlider.maximumValue = 1
        timeSlider.value = 0
        timeSlider.translatesAutoresizingMaskIntoConstraints = false
        timeSlider.tintColor = .systemBlue
        
        // Volume controls
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = 1
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.tintColor = .systemBlue
        
        volumeButton.setTitle("🔊", for: .normal)
        volumeButton.titleLabel?.font = .systemFont(ofSize: 16)
        volumeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Fullscreen button
        fullscreenButton.setTitle("⛶", for: .normal)
        fullscreenButton.titleLabel?.font = .systemFont(ofSize: 16)
        fullscreenButton.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(playPauseButton)
        addSubview(currentTimeLabel)
        addSubview(timeSlider)
        addSubview(totalTimeLabel)
        addSubview(volumeButton)
        addSubview(volumeSlider)
        addSubview(fullscreenButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Play button
            playPauseButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            playPauseButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 44),
            playPauseButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Current time label
            currentTimeLabel.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 8),
            currentTimeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Time slider
            timeSlider.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 8),
            timeSlider.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Total time label
            totalTimeLabel.leadingAnchor.constraint(equalTo: timeSlider.trailingAnchor, constant: 8),
            totalTimeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Volume button
            volumeButton.leadingAnchor.constraint(equalTo: totalTimeLabel.trailingAnchor, constant: 16),
            volumeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            volumeButton.widthAnchor.constraint(equalToConstant: 32),
            volumeButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Volume slider
            volumeSlider.leadingAnchor.constraint(equalTo: volumeButton.trailingAnchor, constant: 8),
            volumeSlider.centerYAnchor.constraint(equalTo: centerYAnchor),
            volumeSlider.widthAnchor.constraint(equalToConstant: 80),
            
            // Fullscreen button
            fullscreenButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            fullscreenButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            fullscreenButton.widthAnchor.constraint(equalToConstant: 32),
            fullscreenButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Time slider width constraint
            timeSlider.trailingAnchor.constraint(lessThanOrEqualTo: volumeButton.leadingAnchor, constant: -8)
        ])
    }
    
    private func setupActions() {
        playPauseButton.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)
        timeSlider.addTarget(self, action: #selector(timeSliderChanged), for: .valueChanged)
        volumeSlider.addTarget(self, action: #selector(volumeSliderChanged), for: .valueChanged)
        volumeButton.addTarget(self, action: #selector(volumeButtonTapped), for: .touchUpInside)
        fullscreenButton.addTarget(self, action: #selector(fullscreenButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func playPauseButtonTapped() {
        isPlaying.toggle()
        updatePlayPauseButton()
        delegate?.playButtonTapped()
    }
    
    @objc private func timeSliderChanged() {
        let time = TimeInterval(timeSlider.value) * totalTime
        delegate?.seekToTime(time)
    }
    
    @objc private func volumeSliderChanged() {
        delegate?.volumeChanged(volumeSlider.value)
        updateVolumeButton()
    }
    
    @objc private func volumeButtonTapped() {
        isMuted.toggle()
        if isMuted {
            volumeSlider.value = 0
        } else {
            volumeSlider.value = 1
        }
        delegate?.volumeChanged(volumeSlider.value)
        updateVolumeButton()
    }
    
    @objc private func fullscreenButtonTapped() {
        // Handle fullscreen toggle
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if windowScene.interfaceOrientation.isPortrait {
                // Attempt to rotate to landscape
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            } else {
                // Attempt to rotate to portrait
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            }
        }
    }
    
    // MARK: - UI Updates
    private func updatePlayPauseButton() {
        playPauseButton.setTitle(isPlaying ? "⏸️" : "▶️", for: .normal)
    }
    
    private func updateVolumeButton() {
        if volumeSlider.value == 0 {
            volumeButton.setTitle("🔇", for: .normal)
        } else if volumeSlider.value < 0.5 {
            volumeButton.setTitle("🔉", for: .normal)
        } else {
            volumeButton.setTitle("🔊", for: .normal)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Public Methods
    func updateTime(currentTime: TimeInterval, totalTime: TimeInterval) {
        self.currentTime = currentTime
        self.totalTime = totalTime
        
        currentTimeLabel.text = formatTime(currentTime)
        totalTimeLabel.text = formatTime(totalTime)
        
        if totalTime > 0 {
            timeSlider.value = Float(currentTime / totalTime)
        }
    }
    
    func setPlaying(_ playing: Bool) {
        isPlaying = playing
        updatePlayPauseButton()
    }
    
    func setVolume(_ volume: Float) {
        volumeSlider.value = volume
        updateVolumeButton()
    }
}
