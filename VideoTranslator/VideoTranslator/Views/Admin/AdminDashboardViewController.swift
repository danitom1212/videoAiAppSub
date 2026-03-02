import UIKit

final class AdminDashboardViewController: UIViewController {

    private let analytics: AnalyticsStore
    private let database: SupabaseService
    private var globalAnalytics: GlobalAnalytics?
    private var users: [AppUser] = []
    private var isLoading = false
    
    // UI Components
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = true
        return sv
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        return rc
    }()
    
    // Overview Cards
    private lazy var overviewStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var translationsCard = createMetricCard(title: "Total Translations", value: "0", subtitle: "Last 24 hours", color: .systemBlue)
    private lazy var activeUsersCard = createMetricCard(title: "Active Users", value: "0", subtitle: "Last 24 hours", color: .systemGreen)
    private lazy var totalUsersCard = createMetricCard(title: "Total Users", value: "0", subtitle: "All time", color: .systemOrange)
    
    // Charts Container
    private lazy var chartsStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 20
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var languagesChartView = createBarChartView(title: "Top Languages")
    private lazy var activityChartView = createLineChartView(title: "Daily Activity")
    
    // Users Table
    private lazy var usersTableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(UserTableViewCell.self, forCellReuseIdentifier: "UserCell")
        tv.heightAnchor.constraint(equalToConstant: 300).isActive = true
        return tv
    }()

    init(analytics: AnalyticsStore = AppContainer.shared.analytics, database: SupabaseService = AppContainer.shared.database) {
        self.analytics = analytics
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
        loadData()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Admin Dashboard"
        
        // Add refresh control to navigation
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshData)
        )
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.refreshControl = refreshControl
        
        // Add components to content view
        contentView.addSubview(overviewStackView)
        contentView.addSubview(chartsStackView)
        contentView.addSubview(usersTableView)
        
        // Add cards to overview stack
        overviewStackView.addArrangedSubview(translationsCard)
        overviewStackView.addArrangedSubview(activeUsersCard)
        overviewStackView.addArrangedSubview(totalUsersCard)
        
        // Add charts to charts stack
        chartsStackView.addArrangedSubview(languagesChartView)
        chartsStackView.addArrangedSubview(activityChartView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view constraints
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view constraints
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Overview stack constraints
            overviewStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            overviewStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            overviewStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Charts stack constraints
            chartsStackView.topAnchor.constraint(equalTo: overviewStackView.bottomAnchor, constant: 30),
            chartsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            chartsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Users table constraints
            usersTableView.topAnchor.constraint(equalTo: chartsStackView.bottomAnchor, constant: 30),
            usersTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            usersTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            usersTableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func refreshData() {
        loadData()
    }
    
    private func loadData() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                // Load global analytics
                let fromDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())
                async let globalAnalyticsTask = database.getGlobalAnalytics(fromDate: fromDate)
                async let usersTask = database.getAllUsers(limit: 50)
                
                let (globalAnalytics, users) = try await (globalAnalyticsTask, usersTask)
                
                await MainActor.run {
                    self.globalAnalytics = globalAnalytics
                    self.users = users
                    self.updateUI()
                    self.isLoading = false
                    self.refreshControl.endRefreshing()
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to load data: \(error.localizedDescription)")
                    self.isLoading = false
                    self.refreshControl.endRefreshing()
                }
            }
        }
    }
    
    private func updateUI() {
        guard let analytics = globalAnalytics else { return }
        
        // Update metric cards
        updateMetricCard(translationsCard, value: "\(analytics.totalTranslations)", subtitle: "Last 7 days")
        updateMetricCard(activeUsersCard, value: "\(analytics.uniqueUsers)", subtitle: "Last 7 days")
        updateMetricCard(totalUsersCard, value: "\(users.count)", subtitle: "Total registered")
        
        // Update charts
        updateLanguagesChart(analytics.topLanguages)
        updateActivityChart()
        
        // Reload users table
        usersTableView.reloadData()
    }
    
    private func createMetricCard(title: String, value: String, subtitle: String, color: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 28, weight: .bold)
        valueLabel.textColor = color
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
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
            card.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        return card
    }
    
    private func updateMetricCard(_ card: UIView, value: String, subtitle: String) {
        guard let stackView = card.subviews.first as? UIStackView,
              stackView.arrangedSubviews.count >= 3 else { return }
        
        let valueLabel = stackView.arrangedSubviews[1] as? UILabel
        let subtitleLabel = stackView.arrangedSubviews[2] as? UILabel
        
        valueLabel?.text = value
        subtitleLabel?.text = subtitle
    }
    
    private func createBarChartView(title: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let chartView = SimpleBarChartView()
        chartView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(chartView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            chartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            chartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            chartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            chartView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        container.tag = 1001 // Tag for bar chart
        return container
    }
    
    private func createLineChartView(title: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let chartView = SimpleLineChartView()
        chartView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(chartView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            chartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            chartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            chartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            chartView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        container.tag = 1002 // Tag for line chart
        return container
    }
    
    private func updateLanguagesChart(_ languages: [(language: String, count: Int)]) {
        guard let chartContainer = chartsStackView.arrangedSubviews.first,
              let chartView = chartContainer.subviews.last as? SimpleBarChartView else { return }
        
        chartView.setData(languages)
    }
    
    private func updateActivityChart() {
        guard let chartContainer = chartsStackView.arrangedSubviews.last,
              let chartView = chartContainer.subviews.last as? SimpleLineChartView else { return }
        
        // Mock data for daily activity - in real app, fetch from database
        let mockData = [
            ("Mon", 45),
            ("Tue", 52),
            ("Wed", 38),
            ("Thu", 65),
            ("Fri", 72),
            ("Sat", 48),
            ("Sun", 58)
        ]
        chartView.setData(mockData)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Table View Data Source

extension AdminDashboardViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Recent Users"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath) as! UserTableViewCell
        cell.configure(with: users[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let user = users[indexPath.row]
        let detailVC = UserDetailViewController(user: user, database: database)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
