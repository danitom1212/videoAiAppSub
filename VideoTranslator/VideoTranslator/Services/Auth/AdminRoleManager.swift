import Foundation
import UIKit

enum AdminRole: String, CaseIterable {
    case admin = "admin"
    case moderator = "moderator"
    case viewer = "viewer"
    
    var displayName: String {
        switch self {
        case .admin: return "Administrator"
        case .moderator: return "Moderator"
        case .viewer: return "Viewer"
        }
    }
    
    var permissions: [AdminPermission] {
        switch self {
        case .admin:
            return [.viewAllUsers, .manageUsers, .viewAnalytics, .manageSettings, .exportData, .manageRoles]
        case .moderator:
            return [.viewAllUsers, .viewAnalytics, .exportData]
        case .viewer:
            return [.viewAnalytics]
        }
    }
}

enum AdminPermission: String, CaseIterable {
    case viewAllUsers = "view_all_users"
    case manageUsers = "manage_users"
    case viewAnalytics = "view_analytics"
    case manageSettings = "manage_settings"
    case exportData = "export_data"
    case manageRoles = "manage_roles"
    
    var displayName: String {
        switch self {
        case .viewAllUsers: return "View All Users"
        case .manageUsers: return "Manage Users"
        case .viewAnalytics: return "View Analytics"
        case .manageSettings: return "Manage Settings"
        case .exportData: return "Export Data"
        case .manageRoles: return "Manage Roles"
        }
    }
}

class AdminRoleManager {
    static let shared = AdminRoleManager()
    
    private let database: SupabaseService
    private var currentUserRole: AdminRole?
    private var roleCache: [String: AdminRole] = [:]
    
    private init(database: SupabaseService = AppContainer.shared.database) {
        self.database = database
    }
    
    // MARK: - Public Methods
    
    func getCurrentUserRole() async throws -> AdminRole? {
        guard let userId = AppContainer.shared.auth.currentUser?.id else {
            return nil
        }
        
        let userIdString = userId.uuidString
        
        // Check cache first
        if let cachedRole = roleCache[userIdString] {
            currentUserRole = cachedRole
            return cachedRole
        }
        
        // Fetch from database
        let role = try await fetchUserRole(userId: userIdString)
        roleCache[userIdString] = role
        currentUserRole = role
        
        return role
    }
    
    func hasPermission(_ permission: AdminPermission) -> Bool {
        guard let role = currentUserRole else { return false }
        return role.permissions.contains(permission)
    }
    
    func canAccessAdminDashboard() -> Bool {
        return currentUserRole != nil
    }
    
    func grantRole(to userId: String, role: AdminRole, grantedBy: String) async throws {
        // Check if the current user has permission to manage roles
        guard hasPermission(.manageRoles) else {
            throw AdminError.insufficientPermissions
        }
        
        // Grant the role in database
        try await grantRoleInDatabase(userId: userId, role: role, grantedBy: grantedBy)
        
        // Update cache
        roleCache[userId] = role
        
        // If granting to current user, update current role
        if userId == AppContainer.shared.auth.currentUser?.id?.uuidString {
            currentUserRole = role
        }
    }
    
    func revokeRole(from userId: String) async throws {
        guard hasPermission(.manageRoles) else {
            throw AdminError.insufficientPermissions
        }
        
        try await revokeRoleInDatabase(userId: userId)
        
        // Update cache
        roleCache.removeValue(forKey: userId)
        
        // If revoking from current user, update current role
        if userId == AppContainer.shared.auth.currentUser?.id?.uuidString {
            currentUserRole = nil
        }
    }
    
    func getAllAdminUsers() async throws -> [(user: AppUser, role: AdminRole)] {
        guard hasPermission(.manageRoles) else {
            throw AdminError.insufficientPermissions
        }
        
        return try await fetchAllAdminUsers()
    }
    
    func refreshUserRole() async throws {
        roleCache.removeAll()
        _ = try await getCurrentUserRole()
    }
    
    // MARK: - Private Methods
    
    private func fetchUserRole(userId: String) async throws -> AdminRole? {
        // This would query the admin_roles table in Supabase
        // For now, we'll implement a simple check
        
        // In a real implementation:
        /*
         let response = try await database.client
             .from("admin_roles")
             .select("role")
             .eq("user_id", value: userId)
             .eq("is_active", value: true)
             .single()
             .execute()
         
         if let data = response.data as? [String: Any],
            let roleString = data["role"] as? String,
            let role = AdminRole(rawValue: roleString) {
             return role
         }
         return nil
         */
        
        // Mock implementation for development
        if userId == "admin-user-id" {
            return .admin
        } else if userId == "moderator-user-id" {
            return .moderator
        } else if userId == "viewer-user-id" {
            return .viewer
        }
        
        return nil
    }
    
    private func grantRoleInDatabase(userId: String, role: AdminRole, grantedBy: String) async throws {
        // This would insert into the admin_roles table in Supabase
        /*
         let roleData: [String: Any] = [
             "user_id": userId,
             "role": role.rawValue,
             "granted_by": grantedBy,
             "granted_at": ISO8601DateFormatter().string(from: Date()),
             "is_active": true
         ]
         
         _ = try await database.client
             .from("admin_roles")
             .upsert(roleData)
             .execute()
         */
        
        print("Granting role \(role.rawValue) to user \(userId) by \(grantedBy)")
    }
    
    private func revokeRoleInDatabase(userId: String) async throws {
        // This would update the admin_roles table in Supabase
        /*
         _ = try await database.client
             .from("admin_roles")
             .update(["is_active": false])
             .eq("user_id", value: userId)
             .execute()
         */
        
        print("Revoking role from user \(userId)")
    }
    
    private func fetchAllAdminUsers() async throws -> [(user: AppUser, role: AdminRole)] {
        // This would join users and admin_roles tables in Supabase
        // For now, return empty array
        
        /*
         let response = try await database.client
             .from("admin_roles")
             .select("users(*), role")
             .eq("is_active", value: true)
             .execute()
         
         guard let data = response.data as? [[String: Any]] else {
             return []
         }
         
         return data.compactMap { dict in
             guard let userData = dict["users"] as? [String: Any],
                   let roleString = dict["role"] as? String,
                   let role = AdminRole(rawValue: roleString),
                   let user = AppUser(from: userData) else {
                 return nil
             }
             return (user: user, role: role)
         }
         */
        
        return []
    }
}

// MARK: - Admin Errors

enum AdminError: LocalizedError {
    case insufficientPermissions
    case userNotFound
    case roleAlreadyAssigned
    case cannotRevokeLastAdmin
    case invalidRole
    
    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "You don't have permission to perform this action"
        case .userNotFound:
            return "User not found"
        case .roleAlreadyAssigned:
            return "User already has this role"
        case .cannotRevokeLastAdmin:
            return "Cannot revoke the last administrator role"
        case .invalidRole:
            return "Invalid role specified"
        }
    }
}

// MARK: - Admin Access Control Extension

extension UIViewController {
    func requireAdminRole(permission: AdminPermission? = nil, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let roleManager = AdminRoleManager.shared
                let role = try await roleManager.getCurrentUserRole()
                
                let hasAccess: Bool
                if let permission = permission {
                    hasAccess = role?.permissions.contains(permission) ?? false
                } else {
                    hasAccess = role != nil
                }
                
                await MainActor.run {
                    completion(hasAccess)
                }
            } catch {
                await MainActor.run {
                    completion(false)
                }
            }
        }
    }
    
    func showAdminAccessDenied() {
        let alert = UIAlertController(
            title: "Access Denied",
            message: "You don't have permission to access this feature. Please contact an administrator.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Admin Navigation Controller

class AdminNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check admin access on load
        requireAdminRole { [weak self] hasAccess in
            guard let self = self else { return }
            
            if !hasAccess {
                DispatchQueue.main.async {
                    self.showAdminAccessDenied()
                    self.popViewController(animated: true)
                }
            }
        }
    }
}
