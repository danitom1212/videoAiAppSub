import UIKit

final class UserDetailViewController: UIViewController {
    
    private let user: AppUser
    private let database: SupabaseService
    private var sessionStats: SessionStats?
    private var translationHistory: [TranslationEvent] = []
    
    // UI Components
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 20
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    // User Info Card
    private lazy var userInfoCard = createUserInfoCard()
    
    // Stats Cards
    private lazy var statsStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 12
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    // Translation History Table
    private lazy var historyTableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(TranslationHistoryCell.self, forCellReuseIdentifier: "TranslationCell")
        tv.heightAnchor.constraint(equalToConstant: 300).isActive = true
        return tv
    }()
    
    init(user: AppUser, database: SupabaseService) {
        self.user = user
        self.database = database
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadUserData()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "User Details"
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        stackView.addArrangedSubview(userInfoCard)
        stackView.addArrangedSubview(statsStackView)
        stackView.addArrangedSubview(historyTableView)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(actionTapped)
        )
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func loadUserData() {
        Task {
            do {
                async let statsTask = database.getSessionStats(for: user.id)
                async let historyTask = database.getTranslationHistory(for: user.id, limit: 20)
                
                let (stats, history) = try await (statsTask, historyTask)
                
                await MainActor.run {
                    self.sessionStats = stats
                    self.translationHistory = history
                    self.updateUI()
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to load user data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updateUI() {
        updateUserInfoCard()
        updateStatsCards()
        historyTableView.reloadData()
    }
    
    private func createUserInfoCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let emailLabel = UILabel()
        emailLabel.text = user.email
        emailLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        let nameLabel = UILabel()
        nameLabel.text = user.displayName
        nameLabel.font = .systemFont(ofSize: 16)
        nameLabel.textColor = .secondaryLabel
        
        let createdLabel = UILabel()
        createdLabel.text = "Joined: \(user.createdAt.formatted(date: .abbreviated, time: .omitted))"
        createdLabel.font = .systemFont(ofSize: 14)
        createdLabel.textColor = .tertiaryLabel
        
        let lastLoginLabel = UILabel()
        lastLoginLabel.text = "Last login: \(user.lastLoginAt.formatted(date: .abbreviated, time: .shortened))"
        lastLoginLabel.font = .systemFont(ofSize: 14)
        lastLoginLabel.textColor = .tertiaryLabel
        
        let stackView = UIStackView(arrangedSubviews: [emailLabel, nameLabel, createdLabel, lastLoginLabel])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        
        return card
    }
    
    private func updateUserInfoCard() {
        // User info is static, no need to update
    }
    
    private func updateStatsCards() {
        guard let stats = sessionStats else { return }
        
        statsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let sessionsCard = createStatCard(title: "Total Sessions", value: "\(stats.totalSessions)", subtitle: "All time")
        let watchTimeCard = createStatCard(title: "Watch Time", value: formatDuration(stats.totalWatchTimeSeconds), subtitle: "Total")
        let avgSessionCard = createStatCard(title: "Avg Session", value: formatDuration(stats.averageSessionDuration), subtitle: "Per session")
        let languagesCard = createStatCard(title: "Languages Used", value: "\(stats.languagesUsed.count)", subtitle: "Unique")
        
        statsStackView.addArrangedSubview(sessionsCard)
        statsStackView.addArrangedSubview(watchTimeCard)
        statsStackView.addArrangedSubview(avgSessionCard)
        statsStackView.addArrangedSubview(languagesCard)
    }
    
    private func createStatCard(title: String, value: String, subtitle: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .tertiarySystemBackground
        card.layer.cornerRadius = 8
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 20, weight: .bold)
        valueLabel.textColor = .label
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .tertiaryLabel
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, valueLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            card.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        return card
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    @objc private func actionTapped() {
        let alert = UIAlertController(title: "User Actions", message: "Choose an action for \(user.displayName)", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Send Email", style: .default) { _ in
            self.sendEmail()
        })
        
        alert.addAction(UIAlertAction(title: "Reset Password", style: .default) { _ in
            self.resetPassword()
        })
        
        alert.addAction(UIAlertAction(title: "Export Data", style: .default) { _ in
            self.exportUserData()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func sendEmail() {
        guard let url = URL(string: "mailto:\(user.email)") else { return }
        UIApplication.shared.open(url)
    }
    
    private func resetPassword() {
        let alert = UIAlertController(
            title: "Reset Password",
            message: "This will send a password reset email to \(user.email)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Send Reset", style: .default) { _ in
            // In a real app, this would call Supabase to send password reset
            self.showSuccess("Password reset email sent")
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func exportUserData() {
        let alert = UIAlertController(
            title: "Export User Data",
            message: "Export all data for \(user.displayName)?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Export", style: .default) { _ in
            self.performExport()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func performExport() {
        // Create a simple text export
        var exportText = "User Data Export\n"
        exportText += "================\n\n"
        exportText += "Email: \(user.email)\n"
        exportText += "Name: \(user.displayName)\n"
        exportText += "Joined: \(user.createdAt)\n"
        exportText += "Last Login: \(user.lastLoginAt)\n\n"
        
        if let stats = sessionStats {
            exportText += "Session Statistics\n"
            exportText += "-----------------\n"
            exportText += "Total Sessions: \(stats.totalSessions)\n"
            exportText += "Watch Time: \(formatDuration(stats.totalWatchTimeSeconds))\n"
            exportText += "Average Session: \(formatDuration(stats.averageSessionDuration))\n"
            exportText += "Languages Used: \(stats.languagesUsed.joined(separator: ", "))\n\n"
        }
        
        exportText += "Recent Translations (\(translationHistory.count))\n"
        exportText += "-------------------\n"
        for translation in translationHistory.prefix(10) {
            exportText += "\(translation.timestamp): \(translation.sourceLanguage) → \(translation.targetLanguage)\n"
            exportText += "Duration: \(translation.durationMs)ms\n"
            exportText += "Text: \(translation.originalText.prefix(100))...\n\n"
        }
        
        // Share the export
        let activityVC = UIActivityViewController(
            activityItems: [exportText],
            applicationActivities: nil
        )
        
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(activityVC, animated: true)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showSuccess(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Table View Data Source

extension UserDetailViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return translationHistory.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Recent Translations"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TranslationCell", for: indexPath) as! TranslationHistoryCell
        cell.configure(with: translationHistory[indexPath.row])
        return cell
    }
}

// MARK: - Translation History Cell

class TranslationHistoryCell: UITableViewCell {
    static let identifier = "TranslationCell"
    
    private let languagesLabel = UILabel()
    private let durationLabel = UILabel()
    private let timestampLabel = UILabel()
    private let previewLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        languagesLabel.font = .systemFont(ofSize: 16, weight: .medium)
        durationLabel.font = .systemFont(ofSize: 14)
        durationLabel.textColor = .secondaryLabel
        timestampLabel.font = .systemFont(ofSize: 12)
        timestampLabel.textColor = .tertiaryLabel
        previewLabel.font = .systemFont(ofSize: 14)
        previewLabel.textColor = .secondaryLabel
        previewLabel.numberOfLines = 2
        
        let topStackView = UIStackView(arrangedSubviews: [languagesLabel, durationLabel])
        topStackView.axis = .horizontal
        topStackView.spacing = 12
        
        let stackView = UIStackView(arrangedSubviews: [topStackView, timestampLabel, previewLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with translation: TranslationEvent) {
        languagesLabel.text = "\(translation.sourceLanguage) → \(translation.targetLanguage)"
        durationLabel.text = "\(translation.durationMs)ms"
        timestampLabel.text = translation.timestamp.formatted(date: .abbreviated, time: .shortened)
        previewLabel.text = translation.originalText.prefix(100).description + (translation.originalText.count > 100 ? "..." : "")
    }
}
