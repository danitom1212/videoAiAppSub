import UIKit

final class LoginViewController: UIViewController {

    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let signInButton = UIButton(type: .system)
    private let googleButton = UIButton(type: .system)
    private let signUpButton = UIButton(type: .system)

    private let auth: AuthProviding
    private let analytics: AnalyticsStore

    init(auth: AuthProviding = AppContainer.shared.auth, analytics: AnalyticsStore = AppContainer.shared.analytics) {
        self.auth = auth
        self.analytics = analytics
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Sign In"

        setupUI()
    }

    private func setupUI() {
        emailField.placeholder = "Email"
        emailField.autocapitalizationType = .none
        emailField.keyboardType = .emailAddress
        emailField.borderStyle = .roundedRect
        emailField.translatesAutoresizingMaskIntoConstraints = false

        passwordField.placeholder = "Password"
        passwordField.isSecureTextEntry = true
        passwordField.borderStyle = .roundedRect
        passwordField.translatesAutoresizingMaskIntoConstraints = false

        signInButton.setTitle("Sign In", for: .normal)
        signInButton.backgroundColor = .systemBlue
        signInButton.setTitleColor(.white, for: .normal)
        signInButton.layer.cornerRadius = 10
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)

        googleButton.setTitle("Continue with Google", for: .normal)
        googleButton.backgroundColor = .systemRed
        googleButton.setTitleColor(.white, for: .normal)
        googleButton.layer.cornerRadius = 10
        googleButton.translatesAutoresizingMaskIntoConstraints = false
        googleButton.addTarget(self, action: #selector(googleTapped), for: .touchUpInside)

        signUpButton.setTitle("Create account", for: .normal)
        signUpButton.translatesAutoresizingMaskIntoConstraints = false
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [emailField, passwordField, signInButton, googleButton, signUpButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        signInButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        googleButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }

    @objc private func signInTapped() {
        let email = emailField.text ?? ""
        let password = passwordField.text ?? ""

        auth.signIn(email: email, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self.analytics.track(AnalyticsEvent(type: .signIn, userEmail: user.email))
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }

    @objc private func googleTapped() {
        auth.signInWithGoogle { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self.analytics.track(AnalyticsEvent(type: .signIn, userEmail: user.email))
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }

    @objc private func signUpTapped() {
        let vc = SignupViewController(auth: auth, analytics: analytics)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
