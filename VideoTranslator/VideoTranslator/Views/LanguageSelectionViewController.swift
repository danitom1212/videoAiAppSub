import UIKit

protocol LanguageSelectionDelegate: AnyObject {
    func didSelectLanguage(sourceLanguage: Language, targetLanguage: Language)
}

class LanguageSelectionViewController: UIViewController {
    
    // MARK: - UI Components
    private let sourceLanguageLabel: UILabel
    private let targetLanguageLabel: UILabel
    private let sourceLanguageTableView: UITableView
    private let targetLanguageTableView: UITableView
    private let swapButton: UIButton
    private let confirmButton: UIBarButtonItem
    
    // MARK: - Properties
    weak var delegate: LanguageSelectionDelegate?
    private var selectedSourceLanguage: Language = Language.language(for: "en")!
    private var selectedTargetLanguage: Language = Language.language(for: "es")!
    private let languages = Language.supportedLanguages
    
    // MARK: - Initialization
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        sourceLanguageLabel = UILabel()
        targetLanguageLabel = UILabel()
        sourceLanguageTableView = UITableView()
        targetLanguageTableView = UITableView()
        swapButton = UIButton()
        confirmButton = UIBarButtonItem()
        
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
        setupNavigation()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Title labels
        sourceLanguageLabel.text = "Source Language"
        sourceLanguageLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        sourceLanguageLabel.textAlignment = .center
        sourceLanguageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        targetLanguageLabel.text = "Target Language"
        targetLanguageLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        targetLanguageLabel.textAlignment = .center
        targetLanguageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Table views
        sourceLanguageTableView.delegate = self
        sourceLanguageTableView.dataSource = self
        sourceLanguageTableView.register(LanguageCell.self, forCellReuseIdentifier: "LanguageCell")
        sourceLanguageTableView.translatesAutoresizingMaskIntoConstraints = false
        sourceLanguageTableView.layer.cornerRadius = 12
        sourceLanguageTableView.layer.borderWidth = 1
        sourceLanguageTableView.layer.borderColor = UIColor.systemGray4.cgColor
        
        targetLanguageTableView.delegate = self
        targetLanguageTableView.dataSource = self
        targetLanguageTableView.register(LanguageCell.self, forCellReuseIdentifier: "LanguageCell")
        targetLanguageTableView.translatesAutoresizingMaskIntoConstraints = false
        targetLanguageTableView.layer.cornerRadius = 12
        targetLanguageTableView.layer.borderWidth = 1
        targetLanguageTableView.layer.borderColor = UIColor.systemGray4.cgColor
        
        // Swap button
        swapButton.setTitle("⇅", for: .normal)
        swapButton.titleLabel?.font = .systemFont(ofSize: 24)
        swapButton.backgroundColor = .systemBlue
        swapButton.setTitleColor(.white, for: .normal)
        swapButton.layer.cornerRadius = 25
        swapButton.translatesAutoresizingMaskIntoConstraints = false
        swapButton.addTarget(self, action: #selector(swapButtonTapped), for: .touchUpInside)
        
        // Add subviews
        view.addSubview(sourceLanguageLabel)
        view.addSubview(targetLanguageLabel)
        view.addSubview(sourceLanguageTableView)
        view.addSubview(targetLanguageTableView)
        view.addSubview(swapButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Source language label
            sourceLanguageLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            sourceLanguageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sourceLanguageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Source language table view
            sourceLanguageTableView.topAnchor.constraint(equalTo: sourceLanguageLabel.bottomAnchor, constant: 10),
            sourceLanguageTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sourceLanguageTableView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.45),
            sourceLanguageTableView.heightAnchor.constraint(equalToConstant: 300),
            
            // Target language label
            targetLanguageLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            targetLanguageLabel.leadingAnchor.constraint(equalTo: sourceLanguageTableView.trailingAnchor, constant: 20),
            targetLanguageTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Target language table view
            targetLanguageTableView.topAnchor.constraint(equalTo: targetLanguageLabel.bottomAnchor, constant: 10),
            targetLanguageTableView.leadingAnchor.constraint(equalTo: sourceLanguageTableView.trailingAnchor, constant: 20),
            targetLanguageTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            targetLanguageTableView.heightAnchor.constraint(equalToConstant: 300),
            
            // Swap button
            swapButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            swapButton.topAnchor.constraint(equalTo: sourceLanguageTableView.bottomAnchor, constant: 20),
            swapButton.widthAnchor.constraint(equalToConstant: 50),
            swapButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupNavigation() {
        title = "Select Languages"
        
        confirmButton.title = "Confirm"
        confirmButton.style = .done
        confirmButton.target = self
        confirmButton.action = #selector(confirmButtonTapped)
        
        navigationItem.rightBarButtonItem = confirmButton
        
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelButtonTapped))
        navigationItem.leftBarButtonItem = cancelButton
    }
    
    // MARK: - Actions
    @objc private func swapButtonTapped() {
        let temp = selectedSourceLanguage
        selectedSourceLanguage = selectedTargetLanguage
        selectedTargetLanguage = temp
        
        sourceLanguageTableView.reloadData()
        targetLanguageTableView.reloadData()
    }
    
    @objc private func confirmButtonTapped() {
        delegate?.didSelectLanguage(sourceLanguage: selectedSourceLanguage, targetLanguage: selectedTargetLanguage)
        dismiss(animated: true)
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource
extension LanguageSelectionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return languages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LanguageCell", for: indexPath) as! LanguageCell
        let language = languages[indexPath.row]
        
        cell.configure(with: language)
        
        if tableView == sourceLanguageTableView {
            cell.isSelected = language.code == selectedSourceLanguage.code
        } else {
            cell.isSelected = language.code == selectedTargetLanguage.code
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension LanguageSelectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let language = languages[indexPath.row]
        
        if tableView == sourceLanguageTableView {
            selectedSourceLanguage = language
        } else {
            selectedTargetLanguage = language
        }
        
        tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
}

// MARK: - LanguageCell
class LanguageCell: UITableViewCell {
    
    private let flagLabel: UILabel
    private let nameLabel: UILabel
    private let nativeNameLabel: UILabel
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        flagLabel = UILabel()
        nameLabel = UILabel()
        nativeNameLabel = UILabel()
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        flagLabel.font = .systemFont(ofSize: 24)
        flagLabel.translatesAutoresizingMaskIntoConstraints = false
        
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        nativeNameLabel.font = .systemFont(ofSize: 14)
        nativeNameLabel.textColor = .secondaryLabel
        nativeNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(flagLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(nativeNameLabel)
        
        NSLayoutConstraint.activate([
            flagLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            flagLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            flagLabel.widthAnchor.constraint(equalToConstant: 30),
            
            nameLabel.leadingAnchor.constraint(equalTo: flagLabel.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            nativeNameLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            nativeNameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            nativeNameLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            nativeNameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with language: Language) {
        flagLabel.text = language.flag
        nameLabel.text = language.name
        nativeNameLabel.text = language.nativeName
    }
    
    override var isSelected: Bool {
        didSet {
            accessoryType = isSelected ? .checkmark : .none
            backgroundColor = isSelected ? UIColor.systemBlue.withAlphaComponent(0.1) : .clear
        }
    }
}
