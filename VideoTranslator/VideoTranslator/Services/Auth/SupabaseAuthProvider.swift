import Foundation

class SupabaseAuthProvider: AuthProviding {
    static let shared = SupabaseAuthProvider()
    
    private let client: SupabaseClient
    internal var currentUser: AppUser? {
        didSet {
            // Add a didSet observer to update the isAuthenticated property
            // This is not strictly necessary, but it's a good practice to keep the two properties in sync
            // However, since the property is internal, it's not clear who would be setting it directly
            // If it's only set internally, then this observer is not needed
        }
    }
    
    private init() {
        // TODO: Replace with your actual Supabase URL and Anon Key
        let supabaseURL = URL(string: "https://YOUR_PROJECT.supabase.co")!
        let supabaseKey = "YOUR_ANON_KEY"
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }
    
    // MARK: - AuthProviding Protocol
    
    var isAuthenticated: Bool {
        return currentUser != nil
    }
    
    var currentUser: AppUser? {
        return self.currentUser
    }
    
    func signIn(email: String, password: String) async throws -> AppUser {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            
            guard let user = session.user else {
                throw AuthError.signInFailed
            }
            
            let appUser = AppUser(
                id: user.id.uuidString,
                email: user.email ?? "",
                displayName: user.userMetadata["display_name"] as? String ?? user.email?.components(separatedBy: "@").first ?? "",
                isAnonymous: false,
                createdAt: Date(),
                lastLoginAt: Date()
            )
            
            self.currentUser = appUser
            
            // Save user profile to database
            try await saveUserProfile(appUser)
            
            return appUser
        } catch {
            throw AuthError.signInFailed
        }
    }
    
    func signUp(email: String, password: String, displayName: String) async throws -> AppUser {
        do {
            let session = try await client.auth.signUp(email: email, password: password, data: ["display_name": displayName])
            
            guard let user = session.user else {
                throw AuthError.signUpFailed
            }
            
            let appUser = AppUser(
                id: user.id.uuidString,
                email: user.email ?? "",
                displayName: displayName,
                isAnonymous: false,
                createdAt: Date(),
                lastLoginAt: Date()
            )
            
            self.currentUser = appUser
            
            // Save user profile to database
            try await saveUserProfile(appUser)
            
            return appUser
        } catch {
            throw AuthError.signUpFailed
        }
    }
    
    func signInWithGoogle() async throws -> AppUser {
        do {
            // Configure Google OAuth
            let session = try await client.auth.signInWithOAuth(provider: .google, redirectTo: URL(string: "videotranslator://auth-callback")!)
            
            // Note: In a real app, you'd handle the OAuth callback
            // For now, we'll simulate a successful Google sign-in
            
            throw AuthError.notImplemented
        } catch {
            throw AuthError.signInFailed
        }
    }
    
    func signOut() async throws {
        do {
            try await client.auth.signOut()
            self.currentUser = nil
        } catch {
            throw AuthError.signOutFailed
        }
    }
    
    func refreshSession() async throws -> Bool {
        do {
            let session = try await client.auth.refreshSession()
            
            guard let user = session.user else {
                return false
            }
            
            // Update current user with fresh data
            if var existingUser = self.currentUser {
                existingUser.lastLoginAt = Date()
                self.currentUser = existingUser
            }
            
            return true
        } catch {
            return false
        }
    }
    
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        
        do {
            // Delete user data from database first
            try await deleteUserProfile(user.id)
            
            // Then delete auth account
            try await client.auth.admin.deleteUser(uuid: UUID(uuidString: user.id)!)
            
            self.currentUser = nil
        } catch {
            throw AuthError.accountDeletionFailed
        }
    }
    
    // MARK: - Private Methods
    
    private func saveUserProfile(_ user: AppUser) async throws {
        let userData: [String: Any] = [
            "id": user.id,
            "email": user.email,
            "display_name": user.displayName,
            "is_anonymous": user.isAnonymous,
            "created_at": ISO8601DateFormatter().string(from: user.createdAt),
            "last_login_at": ISO8601DateFormatter().string(from: user.lastLoginAt),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        _ = try await client.database
            .from("users")
            .upsert(userData)
            .execute()
    }
    
    private func deleteUserProfile(_ userId: String) async throws {
        _ = try await client.database
            .from("users")
            .delete()
            .eq("id", value: userId)
            .execute()
    }
    
    // MARK: - Configuration
    
    func configure(supabaseURL: String, supabaseKey: String) {
        // Reconfigure client with new credentials
        // This would typically be called during app startup
    }
}
