import UIKit

final class SignupViewController: UIViewController {

    private let nameField = UITextField()
    private let emailField = UITextField()
    private let passwordField = UITextField()
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
        title = "Sign Up"

        setupUI()
    }

    private func setupUI() {
        nameField.placeholder = "Name"
        nameField.borderStyle = .roundedRect
        nameField.translatesAutoresizingMaskIntoConstraints = false

        emailField.placeholder = "Email"
        emailField.autocapitalizationType = .none
        emailField.keyboardType = .emailAddress
        emailField.borderStyle = .roundedRect
        emailField.translatesAutoresizingMaskIntoConstraints = false

        passwordField.placeholder = "Password (min 6 chars)"
        passwordField.isSecureTextEntry = true
        passwordField.borderStyle = .roundedRect
        passwordField.translatesAutoresizingMaskIntoConstraints = false

        signUpButton.setTitle("Create account", for: .normal)
        signUpButton.backgroundColor = .systemGreen
        signUpButton.setTitleColor(.white, for: .normal)
        signUpButton.layer.cornerRadius = 10
        signUpButton.translatesAutoresizingMaskIntoConstraints = false
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [nameField, emailField, passwordField, signUpButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        signUpButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }

    @objc private func signUpTapped() {
        let name = nameField.text ?? ""
        let email = emailField.text ?? ""
        let password = passwordField.text ?? ""

        auth.signUp(email: email, password: password, displayName: name.isEmpty ? email : name) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self.analytics.track(AnalyticsEvent(type: .signUp, userEmail: user.email))
                    self.navigationController?.popViewController(animated: true)
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
