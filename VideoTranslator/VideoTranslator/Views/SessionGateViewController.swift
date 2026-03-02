import UIKit

final class SessionGateViewController: UIViewController {

    private let auth: AuthProviding

    init(auth: AuthProviding = AppContainer.shared.auth) {
        self.auth = auth
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged), name: .authSessionChanged, object: nil)
        sessionChanged()
    }

    @objc private func sessionChanged() {
        let next: UIViewController
        if auth.currentUser == nil {
            next = UINavigationController(rootViewController: LoginViewController())
        } else {
            next = UINavigationController(rootViewController: VideoPlayerViewController())
        }

        setRoot(child: next)
    }

    private func setRoot(child: UIViewController) {
        children.forEach { $0.willMove(toParent: nil); $0.view.removeFromSuperview(); $0.removeFromParent() }

        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        child.didMove(toParent: self)
    }
}
