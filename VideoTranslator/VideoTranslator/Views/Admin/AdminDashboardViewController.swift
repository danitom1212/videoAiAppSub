import UIKit

final class AdminDashboardViewController: UIViewController {

    private let analytics: AnalyticsStore
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private enum Section: Int, CaseIterable {
        case overview
        case topLanguages
    }

    init(analytics: AnalyticsStore = AppContainer.shared.analytics) {
        self.analytics = analytics
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Admin"

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearTapped))

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .analyticsUpdated, object: nil)
    }

    @objc private func clearTapped() {
        let alert = UIAlertController(title: "Clear analytics", message: "This clears local analytics stored on the device.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            self.analytics.clear()
        })
        present(alert, animated: true)
    }

    @objc private func reload() {
        tableView.reloadData()
    }
}

extension AdminDashboardViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let s = Section(rawValue: section) else { return 0 }
        switch s {
        case .overview:
            return 3
        case .topLanguages:
            return max(analytics.topTargetLanguages().count, 1)
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let s = Section(rawValue: section) else { return nil }
        switch s {
        case .overview:
            return "Overview (Last 24h)"
        case .topLanguages:
            return "Top target languages"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.selectionStyle = .none

        guard let s = Section(rawValue: indexPath.section) else { return cell }
        switch s {
        case .overview:
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Translations: \(analytics.translationsCountLast24h())"
            case 1:
                cell.textLabel?.text = "Active users: \(analytics.activeUsersLast24h())"
            default:
                cell.textLabel?.text = "Events stored: \(analytics.events.count)"
            }
        case .topLanguages:
            let top = analytics.topTargetLanguages()
            if top.isEmpty {
                cell.textLabel?.text = "No data yet"
            } else {
                let item = top[indexPath.row]
                cell.textLabel?.text = "\(item.code): \(item.count)"
            }
        }

        return cell
    }
}
