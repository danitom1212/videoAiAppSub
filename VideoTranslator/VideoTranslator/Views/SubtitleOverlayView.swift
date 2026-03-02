import UIKit

class SubtitleOverlayView: UIView {
    
    // MARK: - UI Components
    private let subtitleLabel: UILabel
    private let originalTextLabel: UILabel
    private let containerView: UIView
    
    // MARK: - Properties
    private var currentSubtitle: Subtitle?
    private var showOriginal: Bool = false
    
    // MARK: - Customization Properties
    var subtitleStyle: SubtitleStyle = .default {
        didSet {
            updateStyle()
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        subtitleLabel = UILabel()
        originalTextLabel = UILabel()
        containerView = UIView()
        
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        isUserInteractionEnabled = true
        backgroundColor = .clear
        
        // Container view
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Subtitle label
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textColor = .white
        subtitleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(subtitleLabel)
        
        // Original text label
        originalTextLabel.textAlignment = .center
        originalTextLabel.numberOfLines = 0
        originalTextLabel.textColor = .lightGray
        originalTextLabel.font = .systemFont(ofSize: 14, weight: .regular)
        originalTextLabel.translatesAutoresizingMaskIntoConstraints = false
        originalTextLabel.isHidden = true
        containerView.addSubview(originalTextLabel)
        
        setupConstraints()
        updateStyle()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -100),
            
            // Subtitle label
            subtitleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Original text label
            originalTextLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            originalTextLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            originalTextLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            originalTextLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Actions
    @objc private func viewTapped() {
        showOriginal.toggle()
        updateSubtitleDisplay()
    }
    
    // MARK: - Public Methods
    func updateSubtitle(_ subtitle: Subtitle?) {
        currentSubtitle = subtitle
        updateSubtitleDisplay()
    }
    
    func setStyle(_ style: SubtitleStyle) {
        subtitleStyle = style
    }
    
    // MARK: - Private Methods
    private func updateSubtitleDisplay() {
        guard let subtitle = currentSubtitle else {
            hideSubtitle()
            return
        }
        
        showSubtitle()
        
        if showOriginal, let translatedText = subtitle.translatedText {
            subtitleLabel.text = translatedText
            originalTextLabel.text = subtitle.originalText
            originalTextLabel.isHidden = false
        } else if let translatedText = subtitle.translatedText {
            subtitleLabel.text = translatedText
            originalTextLabel.isHidden = true
        } else {
            subtitleLabel.text = subtitle.originalText
            originalTextLabel.isHidden = true
        }
    }
    
    private func showSubtitle() {
        UIView.animate(withDuration: 0.3) {
            self.containerView.alpha = 1
        }
    }
    
    private func hideSubtitle() {
        UIView.animate(withDuration: 0.3) {
            self.containerView.alpha = 0
        }
    }
    
    private func updateStyle() {
        containerView.backgroundColor = subtitleStyle.backgroundColor
        subtitleLabel.textColor = subtitleStyle.textColor
        subtitleLabel.font = subtitleStyle.font
        originalTextLabel.textColor = subtitleStyle.originalTextColor
        originalTextLabel.font = subtitleStyle.originalFont
        containerView.layer.cornerRadius = subtitleStyle.cornerRadius
    }
}

// MARK: - SubtitleStyle
struct SubtitleStyle {
    let backgroundColor: UIColor
    let textColor: UIColor
    let originalTextColor: UIColor
    let font: UIFont
    let originalFont: UIFont
    let cornerRadius: CGFloat
    
    static let `default` = SubtitleStyle(
        backgroundColor: UIColor.black.withAlphaComponent(0.7),
        textColor: .white,
        originalTextColor: .lightGray,
        font: .systemFont(ofSize: 18, weight: .medium),
        originalFont: .systemFont(ofSize: 14, weight: .regular),
        cornerRadius: 8
    )
    
    static let minimal = SubtitleStyle(
        backgroundColor: UIColor.black.withAlphaComponent(0.5),
        textColor: .white,
        originalTextColor: .white.withAlphaComponent(0.7),
        font: .systemFont(ofSize: 16, weight: .regular),
        originalFont: .systemFont(ofSize: 12, weight: .regular),
        cornerRadius: 4
    )
    
    static let prominent = SubtitleStyle(
        backgroundColor: UIColor.black.withAlphaComponent(0.9),
        textColor: .white,
        originalTextColor: .white,
        font: .systemFont(ofSize: 20, weight: .bold),
        originalFont: .systemFont(ofSize: 16, weight: .medium),
        cornerRadius: 12
    )
}
