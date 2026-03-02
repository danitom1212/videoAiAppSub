import Foundation

protocol AuthProviding {
    var currentUser: AppUser? { get }

    func restoreSession()

    func signUp(email: String, password: String, displayName: String, completion: @escaping (Result<AppUser, Error>) -> Void)
    func signIn(email: String, password: String, completion: @escaping (Result<AppUser, Error>) -> Void)

    func signInWithGoogle(completion: @escaping (Result<AppUser, Error>) -> Void)

    func signOut()
}

enum AuthError: LocalizedError {
    case invalidEmail
    case weakPassword
    case userAlreadyExists
    case invalidCredentials
    case cancelled
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Invalid email address."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .userAlreadyExists:
            return "User already exists."
        case .invalidCredentials:
            return "Invalid email or password."
        case .cancelled:
            return "Operation cancelled."
        case .unknown:
            return "Unknown authentication error."
        }
    }
}
