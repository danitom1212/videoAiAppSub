import AVKit
import AVFoundation

class AVPlayerView: UIView {
    
    var player: AVPlayer? {
        get { playerViewController.player }
        set { playerViewController.player = newValue }
    }
    
    private let playerViewController = AVPlayerViewController()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPlayerView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPlayerView()
    }
    
    private func setupPlayerView() {
        addSubview(playerViewController.view)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            playerViewController.view.topAnchor.constraint(equalTo: topAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Configure player controller
        playerViewController.showsPlaybackControls = false
        playerViewController.allowsPictureInPicturePlayback = true
        playerViewController.updatesNowPlayingInfoCenter = false
    }
}
