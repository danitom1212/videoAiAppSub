import Foundation

final class MockAuthProvider: AuthProviding {

    private enum Keys {
        static let users = "MockAuthProvider.Users"
        static let passwordByEmail = "MockAuthProvider.PasswordByEmail"
        static let currentUserEmail = "MockAuthProvider.CurrentUserEmail"
        static let adminEmails = "MockAuthProvider.AdminEmails"
    }

    private let defaults: UserDefaults

    private(set) var currentUser: AppUser?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func restoreSession() {
        let email = defaults.string(forKey: Keys.currentUserEmail)
        guard let email else {
            currentUser = nil
            return
        }

        let users = loadUsers()
        currentUser = users[email]
    }

    func signUp(email: String, password: String, displayName: String, completion: @escaping (Result<AppUser, Error>) -> Void) {
        guard isValidEmail(email) else {
            completion(.failure(AuthError.invalidEmail))
            return
        }
        guard password.count >= 6 else {
            completion(.failure(AuthError.weakPassword))
            return
        }

        var users = loadUsers()
        if users[email] != nil {
            completion(.failure(AuthError.userAlreadyExists))
            return
        }

        let role: AppUser.Role = isAdminEmail(email) ? .admin : .user
        let user = AppUser(email: email, displayName: displayName, role: role)
        users[email] = user
        saveUsers(users)

        var passwords = loadPasswords()
        passwords[email] = password
        savePasswords(passwords)

        setCurrentUser(user)
        completion(.success(user))
    }

    func signIn(email: String, password: String, completion: @escaping (Result<AppUser, Error>) -> Void) {
        var users = loadUsers()
        let passwords = loadPasswords()

        guard let storedPassword = passwords[email], storedPassword == password, var user = users[email] else {
            completion(.failure(AuthError.invalidCredentials))
            return
        }

        user.lastLoginAt = Date()
        user.role = isAdminEmail(email) ? .admin : user.role
        users[email] = user
        saveUsers(users)

        setCurrentUser(user)
        completion(.success(user))
    }

    func signInWithGoogle(completion: @escaping (Result<AppUser, Error>) -> Void) {
        let email = "google.user@example.com"

        var users = loadUsers()
        var user = users[email] ?? AppUser(email: email, displayName: "Google User", role: isAdminEmail(email) ? .admin : .user)
        user.lastLoginAt = Date()
        users[email] = user
        saveUsers(users)

        setCurrentUser(user)
        completion(.success(user))
    }

    func signOut() {
        defaults.removeObject(forKey: Keys.currentUserEmail)
        currentUser = nil
        NotificationCenter.default.post(name: .authSessionChanged, object: nil)
    }

    func addAdminEmail(_ email: String) {
        var set = Set(loadAdminEmails())
        set.insert(email.lowercased())
        defaults.set(Array(set), forKey: Keys.adminEmails)
    }

    private func setCurrentUser(_ user: AppUser) {
        currentUser = user
        defaults.set(user.email, forKey: Keys.currentUserEmail)
        NotificationCenter.default.post(name: .authSessionChanged, object: nil)
    }

    private func isAdminEmail(_ email: String) -> Bool {
        loadAdminEmails().contains(email.lowercased())
    }

    private func loadAdminEmails() -> [String] {
        (defaults.array(forKey: Keys.adminEmails) as? [String]) ?? []
    }

    private func loadUsers() -> [String: AppUser] {
        guard let data = defaults.data(forKey: Keys.users) else { return [:] }
        return (try? JSONDecoder().decode([String: AppUser].self, from: data)) ?? [:]
    }

    private func saveUsers(_ users: [String: AppUser]) {
        guard let data = try? JSONEncoder().encode(users) else { return }
        defaults.set(data, forKey: Keys.users)
    }

    private func loadPasswords() -> [String: String] {
        guard let data = defaults.data(forKey: Keys.passwordByEmail) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    private func savePasswords(_ passwords: [String: String]) {
        guard let data = try? JSONEncoder().encode(passwords) else { return }
        defaults.set(data, forKey: Keys.passwordByEmail)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return false }
        return parts[1].contains(".")
    }
}

extension Notification.Name {
    static let authSessionChanged = Notification.Name("AuthSessionChanged")
}
