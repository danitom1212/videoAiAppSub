import Foundation

struct AppUser: Codable, Equatable {
    enum Role: String, Codable {
        case user
        case admin
    }

    let id: UUID
    let email: String
    var displayName: String
    var role: Role
    var createdAt: Date
    var lastLoginAt: Date

    init(id: UUID = UUID(), email: String, displayName: String, role: Role = .user, createdAt: Date = Date(), lastLoginAt: Date = Date()) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.role = role
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
    }
}
