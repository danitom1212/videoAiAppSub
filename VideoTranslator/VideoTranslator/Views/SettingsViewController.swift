import UIKit

class SettingsViewController: UIViewController {
    
    // MARK: - UI Components
    private let tableView: UITableView
    private let apiKeyCell: UITableViewCell
    private let apiKeyTextField: UITextField
    private let subtitleStyleCell: UITableViewCell
    private let subtitleStyleLabel: UILabel
    private let autoTranslateSwitch: UISwitch
    private let clearLearningDataButton: UIButton
    private let learningDataCountLabel: UILabel
    
    // MARK: - Properties
    private let availableSubtitleStyles: [SubtitleStyle] = [.default, .minimal, .prominent]
    private var selectedSubtitleStyleIndex: Int = 0
    private var apiKey: String = ""
    
    // MARK: - Initialization
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        apiKeyCell = UITableViewCell(style: .default, reuseIdentifier: "APIKeyCell")
        apiKeyTextField = UITextField()
        subtitleStyleCell = UITableViewCell(style: .value1, reuseIdentifier: "SubtitleStyleCell")
        subtitleStyleLabel = UILabel()
        autoTranslateSwitch = UISwitch()
        clearLearningDataButton = UIButton(type: .system)
        learningDataCountLabel = UILabel()
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadSettings()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveSettings()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Settings"
        
        // Table view setup
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // API Key cell setup
        apiKeyCell.textLabel?.text = "OpenAI API Key"
        apiKeyTextField.placeholder = "Enter your API key"
        apiKeyTextField.isSecureTextEntry = true
        apiKeyTextField.borderStyle = .roundedRect
        apiKeyTextField.translatesAutoresizingMaskIntoConstraints = false
        apiKeyCell.contentView.addSubview(apiKeyTextField)
        
        // Subtitle style cell setup
        subtitleStyleCell.textLabel?.text = "Subtitle Style"
        subtitleStyleCell.accessoryType = .disclosureIndicator
        subtitleStyleCell.selectionStyle = .none
        
        // Clear learning data button setup
        clearLearningDataButton.setTitle("Clear Learning Data", for: .normal)
        clearLearningDataButton.backgroundColor = .systemRed
        clearLearningDataButton.setTitleColor(.white, for: .normal)
        clearLearningDataButton.layer.cornerRadius = 8
        clearLearningDataButton.translatesAutoresizingMaskIntoConstraints = false
        clearLearningDataButton.addTarget(self, action: #selector(clearLearningDataTapped), for: .touchUpInside)
        
        // Learning data count label setup
        learningDataCountLabel.font = .systemFont(ofSize: 14)
        learningDataCountLabel.textColor = .secondaryLabel
        learningDataCountLabel.textAlignment = .center
        learningDataCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tableView)
        view.addSubview(clearLearningDataButton)
        view.addSubview(learningDataCountLabel)
        
        setupAPIKeyCellConstraints()
        updateLearningDataCount()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7),
            
            clearLearningDataButton.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 20),
            clearLearningDataButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            clearLearningDataButton.widthAnchor.constraint(equalToConstant: 200),
            clearLearningDataButton.heightAnchor.constraint(equalToConstant: 44),
            
            learningDataCountLabel.topAnchor.constraint(equalTo: clearLearningDataButton.bottomAnchor, constant: 8),
            learningDataCountLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            learningDataCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupAPIKeyCellConstraints() {
        NSLayoutConstraint.activate([
            apiKeyTextField.leadingAnchor.constraint(equalTo: apiKeyCell.contentView.leadingAnchor, constant: 16),
            apiKeyTextField.trailingAnchor.constraint(equalTo: apiKeyCell.contentView.trailingAnchor, constant: -16),
            apiKeyTextField.centerYAnchor.constraint(equalTo: apiKeyCell.contentView.centerYAnchor),
            apiKeyTextField.heightAnchor.constraint(equalToConstant: 34)
        ])
    }
    
    // MARK: - Settings Management
    private func loadSettings() {
        let userDefaults = UserDefaults.standard
        
        // Load API key
        apiKey = userDefaults.string(forKey: "OpenAI_API_Key") ?? ""
        apiKeyTextField.text = apiKey
        
        // Load subtitle style
        let styleIndex = userDefaults.integer(forKey: "SubtitleStyle")
        selectedSubtitleStyleIndex = availableSubtitleStyles.indices.contains(styleIndex) ? styleIndex : 0
        
        // Load auto-translate setting
        autoTranslateSwitch.isOn = userDefaults.bool(forKey: "AutoTranslate")
    }
    
    private func saveSettings() {
        let userDefaults = UserDefaults.standard
        
        // Save API key
        userDefaults.set(apiKeyTextField.text, forKey: "OpenAI_API_Key")
        
        // Save subtitle style
        userDefaults.set(selectedSubtitleStyleIndex, forKey: "SubtitleStyle")
        
        // Save auto-translate setting
        userDefaults.set(autoTranslateSwitch.isOn, forKey: "AutoTranslate")
    }
    
    private func updateLearningDataCount() {
        let count = LearningManager.shared.getCorrectionsCount()
        learningDataCountLabel.text = "Learning data entries: \(count)"
    }
    
    // MARK: - Actions
    @objc private func clearLearningDataTapped() {
        let alert = UIAlertController(title: "Clear Learning Data", message: "This will remove all your translation corrections and learning data. This action cannot be undone.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            LearningManager.shared.clearCorrections()
            self.updateLearningDataCount()
            
            let confirmationAlert = UIAlertController(title: "Data Cleared", message: "All learning data has been removed.", preferredStyle: .alert)
            confirmationAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(confirmationAlert, animated: true)
        })
        
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        // Check if user has admin permissions
        if hasAdminAccess() {
            return 4 // Add Admin section
        }
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1 // API Key
        case 1: return 2 // Subtitle Style, Auto-translate
        case 2: 
            if hasAdminAccess() {
                return 2 // Admin Dashboard, About
            } else {
                return 1 // About
            }
        case 3: return 1 // About (only when admin section exists)
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            return apiKeyCell
        case 1:
            if indexPath.row == 0 {
                // Subtitle Style
                subtitleStyleCell.detailTextLabel?.text = getStyleName(selectedSubtitleStyleIndex)
                return subtitleStyleCell
            } else {
                // Auto-translate
                let cell = UITableViewCell(style: .default, reuseIdentifier: "AutoTranslateCell")
                cell.textLabel?.text = "Auto-translate"
                cell.selectionStyle = .none
                cell.accessoryView = autoTranslateSwitch
                return cell
            }
        case 2:
            if hasAdminAccess() {
                if indexPath.row == 0 {
                    // Admin Dashboard
                    let cell = UITableViewCell(style: .default, reuseIdentifier: "AdminCell")
                    cell.textLabel?.text = "Admin Dashboard"
                    cell.accessoryType = .disclosureIndicator
                    cell.backgroundColor = .systemBlue.withAlphaComponent(0.1)
                    return cell
                } else {
                    // About
                    let cell = UITableViewCell(style: .default, reuseIdentifier: "AboutCell")
                    cell.textLabel?.text = "About"
                    cell.accessoryType = .disclosureIndicator
                    return cell
                }
            } else {
                // About
                let cell = UITableViewCell(style: .default, reuseIdentifier: "AboutCell")
                cell.textLabel?.text = "About"
                cell.accessoryType = .disclosureIndicator
                return cell
            }
        case 3:
            // About (only when admin section exists)
            let cell = UITableViewCell(style: .default, reuseIdentifier: "AboutCell")
            cell.textLabel?.text = "About"
            cell.accessoryType = .disclosureIndicator
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Translation Service"
        case 1: return "Display"
        case 2: 
            if hasAdminAccess() {
                return "Administration"
            } else {
                return "Information"
            }
        case 3: return "Information"
        default: return nil
        }
    }
}

// MARK: - UITableViewDelegate
extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 1 && indexPath.row == 0 {
            // Show subtitle style selection
            showSubtitleStyleSelection()
        } else if indexPath.section == 2 {
            if hasAdminAccess() {
                if indexPath.row == 0 {
                    // Admin Dashboard
                    showAdminDashboard()
                } else {
                    // Show about screen
                    showAboutScreen()
                }
            } else {
                // Show about screen
                showAboutScreen()
            }
        } else if indexPath.section == 3 && indexPath.row == 0 {
            // Show about screen (only when admin section exists)
            showAboutScreen()
        }
    }
    
    private func hasAdminAccess() -> Bool {
        // For now, return true for development
        // In production, this would check AdminRoleManager.shared.canAccessAdminDashboard()
        return true
    }
    
    private func showAdminDashboard() {
        requireAdminRole { [weak self] hasAccess in
            guard let self = self else { return }
            
            if hasAccess {
                let adminVC = AdminDashboardViewController()
                let navController = UINavigationController(rootViewController: adminVC)
                self.present(navController, animated: true)
            } else {
                self.showAdminAccessDenied()
            }
        }
    }
    
    private func showSubtitleStyleSelection() {
        let alert = UIAlertController(title: "Subtitle Style", message: "Choose your preferred subtitle style", preferredStyle: .actionSheet)

        for (index, _) in availableSubtitleStyles.enumerated() {
            let action = UIAlertAction(title: getStyleName(index), style: .default) { _ in
                self.selectedSubtitleStyleIndex = index
                self.tableView.reloadData()
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = subtitleStyleCell
            popover.sourceRect = subtitleStyleCell.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func showAboutScreen() {
        let aboutVC = AboutViewController()
        let navController = UINavigationController(rootViewController: aboutVC)
        present(navController, animated: true)
    }
    
    private func getStyleName(_ styleIndex: Int) -> String {
        switch styleIndex {
        case 1: return "Minimal"
        case 2: return "Prominent"
        default: return "Default"
        }
    }
}

// MARK: - AboutViewController
class AboutViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "About"
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        let titleLabel = UILabel()
        titleLabel.text = "Video Translator"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let versionLabel = UILabel()
        versionLabel.text = "Version 1.0"
        versionLabel.font = .systemFont(ofSize: 16)
        versionLabel.textAlignment = .center
        versionLabel.textColor = .secondaryLabel
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = "AI-powered video translation app with real-time subtitles in over 60 languages. Features speech-to-text transcription, neural translation, and self-learning capabilities for improved accuracy over time."
        descriptionLabel.font = .systemFont(ofSize: 16)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(versionLabel)
        contentView.addSubview(descriptionLabel)
        
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
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            versionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            versionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            versionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            descriptionLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 20),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissTapped))
    }
    
    @objc private func dismissTapped() {
        dismiss(animated: true)
    }
}

// MARK: - Array Extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
