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
    case notImplemented
    case notAuthenticated
    case signInFailed
    case signUpFailed
    case signOutFailed
    case accountDeletionFailed

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
        case .notImplemented:
            return "This feature is not implemented yet."
        case .notAuthenticated:
            return "User is not authenticated."
        case .signInFailed:
            return "Failed to sign in. Please check your credentials."
        case .signUpFailed:
            return "Failed to create account. Please try again."
        case .signOutFailed:
            return "Failed to sign out. Please try again."
        case .accountDeletionFailed:
            return "Failed to delete account. Please try again."
        }
    }
}
