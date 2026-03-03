import Foundation
import CryptoKit
import LocalAuthentication
import Security

// MARK: - Security Manager
class SecurityManager {
    // MARK: - Properties
    private let configuration: SecurityConfiguration
    private let keychain: KeychainManager
    private let encryptionManager: EncryptionManager
    private let biometricManager: BiometricManager
    private let auditLogger: SecurityAuditLogger
    
    // MARK: - State
    private var failedAttempts = 0
    private var lastFailedAttempt: Date?
    private var isLocked = false
    
    // MARK: - Publishers
    private var securityStateSubject = CurrentValueSubject<SecurityState, Never>(.secure)
    var securityStatePublisher: AnyPublisher<SecurityState, Never> {
        securityStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init(configuration: SecurityConfiguration) {
        self.configuration = configuration
        self.keychain = KeychainManager(configuration: configuration)
        self.encryptionManager = EncryptionManager(configuration: configuration)
        self.biometricManager = BiometricManager(configuration: configuration)
        self.auditLogger = SecurityAuditLogger()
        
        setupSecurityMonitoring()
    }
    
    // MARK: - Public Methods
    
    // MARK: - Encryption
    func encrypt(_ data: Data, key: SecurityKey? = nil) throws -> EncryptedData {
        guard !isLocked else {
            throw SecurityError.securityLocked
        }
        
        let encryptionKey = key ?? try getDefaultKey()
        let encryptedData = try encryptionManager.encrypt(data, with: encryptionKey)
        
        auditLogger.logEvent(.encryptionPerformed, details: ["dataSize": data.count])
        
        return encryptedData
    }
    
    func decrypt(_ encryptedData: EncryptedData, key: SecurityKey? = nil) throws -> Data {
        guard !isLocked else {
            throw SecurityError.securityLocked
        }
        
        let decryptionKey = key ?? try getDefaultKey()
        let decryptedData = try encryptionManager.decrypt(encryptedData, with: decryptionKey)
        
        auditLogger.logEvent(.decryptionPerformed, details: ["dataSize": decryptedData.count])
        
        return decryptedData
    }
    
    // MARK: - Key Management
    func generateKey() throws -> SecurityKey {
        let key = try encryptionManager.generateKey()
        
        auditLogger.logEvent(.keyGenerated, details: ["keyId": key.id])
        
        return key
    }
    
    func storeKey(_ key: SecurityKey, identifier: String) throws {
        try keychain.store(key, identifier: identifier)
        
        auditLogger.logEvent(.keyStored, details: ["keyId": key.id, "identifier": identifier])
    }
    
    func retrieveKey(identifier: String) throws -> SecurityKey? {
        let key = try keychain.retrieve(identifier: identifier)
        
        if key != nil {
            auditLogger.logEvent(.keyRetrieved, details: ["identifier": identifier])
        }
        
        return key
    }
    
    func deleteKey(identifier: String) throws {
        try keychain.delete(identifier: identifier)
        
        auditLogger.logEvent(.keyDeleted, details: ["identifier": identifier])
    }
    
    // MARK: - Authentication
    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        guard configuration.biometricEnabled else {
            throw SecurityError.biometricNotEnabled
        }
        
        let success = try await biometricManager.authenticate(reason: reason)
        
        if success {
            failedAttempts = 0
            isLocked = false
            securityStateSubject.send(.secure)
            
            auditLogger.logEvent(.biometricAuthenticationSucceeded, details: ["reason": reason])
        } else {
            handleFailedAuthentication()
            auditLogger.logEvent(.biometricAuthenticationFailed, details: ["reason": reason])
        }
        
        return success
    }
    
    func authenticateWithPasscode(_ passcode: String) -> Bool {
        guard !isLocked else {
            return false
        }
        
        let storedPasscode = getStoredPasscode()
        let success = passcode == storedPasscode
        
        if success {
            failedAttempts = 0
            isLocked = false
            securityStateSubject.send(.secure)
            
            auditLogger.logEvent(.passcodeAuthenticationSucceeded, details: [])
        } else {
            handleFailedAuthentication()
            auditLogger.logEvent(.passcodeAuthenticationFailed, details: [])
        }
        
        return success
    }
    
    // MARK: - Data Protection
    func secureStore(_ data: Data, identifier: String) throws {
        guard !isLocked else {
            throw SecurityError.securityLocked
        }
        
        let encryptedData = try encrypt(data)
        try keychain.store(encryptedData, identifier: identifier)
        
        auditLogger.logEvent(.dataStored, details: ["identifier": identifier, "dataSize": data.count])
    }
    
    func secureRetrieve(identifier: String) throws -> Data? {
        guard !isLocked else {
            throw SecurityError.securityLocked
        }
        
        guard let encryptedData: EncryptedData = try keychain.retrieve(identifier: identifier) else {
            return nil
        }
        
        let decryptedData = try decrypt(encryptedData)
        
        auditLogger.logEvent(.dataRetrieved, details: ["identifier": identifier, "dataSize": decryptedData.count])
        
        return decryptedData
    }
    
    func secureDelete(identifier: String) throws {
        try keychain.delete(identifier: identifier)
        
        auditLogger.logEvent(.dataDeleted, details: ["identifier": identifier])
    }
    
    // MARK: - Session Management
    func startSession() {
        auditLogger.logEvent(.sessionStarted, details: [])
    }
    
    func endSession() {
        auditLogger.logEvent(.sessionEnded, details: [])
        
        // Clear sensitive data from memory
        clearSensitiveData()
    }
    
    func lockSecurity() {
        isLocked = true
        securityStateSubject.send(.locked)
        
        auditLogger.logEvent(.securityLocked, details: [])
    }
    
    func unlockSecurity() {
        isLocked = false
        securityStateSubject.send(.secure)
        
        auditLogger.logEvent(.securityUnlocked, details: [])
    }
    
    // MARK: - Validation
    func validateSecurityIntegrity() -> SecurityReport {
        let report = SecurityReport()
        
        // Check keychain integrity
        report.keychainIntegrity = keychain.validateIntegrity()
        
        // Check encryption integrity
        report.encryptionIntegrity = encryptionManager.validateIntegrity()
        
        // Check biometric availability
        report.biometricAvailable = biometricManager.isAvailable
        
        // Check for security vulnerabilities
        report.vulnerabilities = checkVulnerabilities()
        
        auditLogger.logEvent(.securityValidationPerformed, details: [
            "keychainIntegrity": report.keychainIntegrity,
            "encryptionIntegrity": report.encryptionIntegrity,
            "biometricAvailable": report.biometricAvailable,
            "vulnerabilitiesCount": report.vulnerabilities.count
        ])
        
        return report
    }
    
    // MARK: - Private Methods
    private func setupSecurityMonitoring() {
        // Monitor failed attempts
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkFailedAttemptsTimeout()
        }
        
        // Monitor session timeout
        Timer.scheduledTimer(withTimeInterval: configuration.sessionTimeout, repeats: false) { [weak self] _ in
            self?.handleSessionTimeout()
        }
    }
    
    private func getDefaultKey() throws -> SecurityKey {
        if let existingKey = try? retrieveKey(identifier: "default") {
            return existingKey
        }
        
        let newKey = try generateKey()
        try storeKey(newKey, identifier: "default")
        return newKey
    }
    
    private func getStoredPasscode() -> String? {
        return UserDefaults.standard.string(forKey: "app_passcode")
    }
    
    private func handleFailedAuthentication() {
        failedAttempts += 1
        lastFailedAttempt = Date()
        
        if failedAttempts >= configuration.maxFailedAttempts {
            lockSecurity()
        }
        
        securityStateSubject.send(.compromised)
    }
    
    private func checkFailedAttemptsTimeout() {
        guard let lastAttempt = lastFailedAttempt else { return }
        
        let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
        let timeoutInterval: TimeInterval = 300 // 5 minutes
        
        if timeSinceLastAttempt > timeoutInterval {
            failedAttempts = 0
            lastFailedAttempt = nil
            securityStateSubject.send(.secure)
        }
    }
    
    private func handleSessionTimeout() {
        lockSecurity()
        auditLogger.logEvent(.sessionTimeout, details: [])
    }
    
    private func clearSensitiveData() {
        // Clear sensitive data from memory
        encryptionManager.clearSensitiveData()
        keychain.clearSensitiveData()
    }
    
    private func checkVulnerabilities() -> [SecurityVulnerability] {
        var vulnerabilities: [SecurityVulnerability] = []
        
        // Check for jailbreak
        if isJailbroken() {
            vulnerabilities.append(.jailbreakDetected)
        }
        
        // Check for debugger
        if isDebuggerAttached() {
            vulnerabilities.append(.debuggerAttached)
        }
        
        // Check for insecure environment
        if isInsecureEnvironment() {
            vulnerabilities.append(.insecureEnvironment)
        }
        
        return vulnerabilities
    }
    
    private func isJailbroken() -> Bool {
        // Check for common jailbreak indicators
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        return false
    }
    
    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.size
        
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        
        if result != 0 {
            return false
        }
        
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    private func isInsecureEnvironment() -> Bool {
        // Check for insecure environment indicators
        return !isRunningInProduction()
    }
    
    private func isRunningInProduction() -> Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}

// MARK: - Security State
enum SecurityState {
    case secure
    case compromised
    case locked
    case vulnerable
    
    var isSecure: Bool {
        switch self {
        case .secure:
            return true
        default:
            return false
        }
    }
}

// MARK: - Security Error
enum SecurityError: LocalizedError {
    case securityLocked
    case biometricNotEnabled
    case biometricNotAvailable
    case encryptionFailed
    case decryptionFailed
    case keyNotFound
    case invalidPasscode
    case maxAttemptsExceeded
    case securityViolation
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .securityLocked:
            return "Security is locked"
        case .biometricNotEnabled:
            return "Biometric authentication is not enabled"
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        case .keyNotFound:
            return "Security key not found"
        case .invalidPasscode:
            return "Invalid passcode"
        case .maxAttemptsExceeded:
            return "Maximum authentication attempts exceeded"
        case .securityViolation:
            return "Security violation detected"
        case .unknown(let error):
            return "Unknown security error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Security Key
struct SecurityKey: Codable {
    let id: String
    let data: Data
    let algorithm: String
    let keySize: Int
    let created: Date
    
    init(id: String = UUID().uuidString, data: Data, algorithm: String = "AES", keySize: Int = 256) {
        self.id = id
        self.data = data
        self.algorithm = algorithm
        self.keySize = keySize
        self.created = Date()
    }
}

// MARK: - Encrypted Data
struct EncryptedData: Codable {
    let data: Data
    let iv: Data
    let algorithm: String
    let keyId: String?
    let timestamp: Date
    
    init(data: Data, iv: Data, algorithm: String = "AES", keyId: String? = nil) {
        self.data = data
        self.iv = iv
        self.algorithm = algorithm
        self.keyId = keyId
        self.timestamp = Date()
    }
}

// MARK: - Security Report
struct SecurityReport {
    var keychainIntegrity: Bool = false
    var encryptionIntegrity: Bool = false
    var biometricAvailable: Bool = false
    var vulnerabilities: [SecurityVulnerability] = []
    var timestamp: Date = Date()
    
    var isSecure: Bool {
        return keychainIntegrity && encryptionIntegrity && vulnerabilities.isEmpty
    }
    
    var riskLevel: SecurityRiskLevel {
        if vulnerabilities.contains(.jailbreakDetected) {
            return .critical
        } else if vulnerabilities.contains(.debuggerAttached) {
            return .high
        } else if !isSecure {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Security Vulnerability
enum SecurityVulnerability {
    case jailbreakDetected
    case debuggerAttached
    case insecureEnvironment
    case weakEncryption
    case outdatedSecurity
    
    var description: String {
        switch self {
        case .jailbreakDetected:
            return "Jailbreak detected"
        case .debuggerAttached:
            return "Debugger attached"
        case .insecureEnvironment:
            return "Insecure environment detected"
        case .weakEncryption:
            return "Weak encryption detected"
        case .outdatedSecurity:
            return "Outdated security measures"
        }
    }
    
    var severity: SecuritySeverity {
        switch self {
        case .jailbreakDetected:
            return .critical
        case .debuggerAttached:
            return .high
        case .insecureEnvironment:
            return .medium
        case .weakEncryption:
            return .high
        case .outdatedSecurity:
            return .medium
        }
    }
}

// MARK: - Security Risk Level
enum SecurityRiskLevel {
    case low
    case medium
    case high
    case critical
    
    var color: String {
        switch self {
        case .low:
            return "green"
        case .medium:
            return "yellow"
        case .high:
            return "orange"
        case .critical:
            return "red"
        }
    }
}

// MARK: - Security Severity
enum SecuritySeverity {
    case low
    case medium
    case high
    case critical
}

// MARK: - Security Audit Logger
class SecurityAuditLogger {
    private var events: [SecurityEvent] = []
    private let maxEvents = 1000
    private let queue = DispatchQueue(label: "SecurityAudit", qos: .utility)
    
    func logEvent(_ event: SecurityEventType, details: [String: Any]) {
        let auditEvent = SecurityEvent(
            type: event,
            timestamp: Date(),
            details: details,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        )
        
        queue.async {
            self.events.append(auditEvent)
            
            // Keep only recent events
            if self.events.count > self.maxEvents {
                self.events.removeFirst(self.events.count - self.maxEvents)
            }
            
            // Log to external service if needed
            self.logToExternalService(auditEvent)
        }
    }
    
    func getEvents(since date: Date? = nil) -> [SecurityEvent] {
        return queue.sync {
            guard let since = date else {
                return events
            }
            
            return events.filter { $0.timestamp >= since }
        }
    }
    
    func getSecurityReport() -> SecurityAuditReport {
        return queue.sync {
            let recentEvents = events.suffix(100)
            
            return SecurityAuditReport(
                totalEvents: events.count,
                recentEvents: recentEvents.count,
                criticalEvents: recentEvents.filter { $0.type.isCritical }.count,
                lastEvent: events.last?.timestamp,
                riskScore: calculateRiskScore()
            )
        }
    }
    
    private func logToExternalService(_ event: SecurityEvent) {
        // Implementation for external logging service
        // This could be sent to a security monitoring service
    }
    
    private func calculateRiskScore() -> Double {
        let recentEvents = events.suffix(100)
        let criticalWeight = 10.0
        let highWeight = 5.0
        let mediumWeight = 2.0
        let lowWeight = 1.0
        
        let score = recentEvents.reduce(0.0) { total, event in
            switch event.type.severity {
            case .critical:
                return total + criticalWeight
            case .high:
                return total + highWeight
            case .medium:
                return total + mediumWeight
            case .low:
                return total + lowWeight
            }
        }
        
        return min(score / 100.0, 1.0) // Normalize to 0-1
    }
}

// MARK: - Security Event
struct SecurityEvent {
    let type: SecurityEventType
    let timestamp: Date
    let details: [String: Any]
    let deviceId: String
}

// MARK: - Security Event Type
enum SecurityEventType {
    case encryptionPerformed
    case decryptionPerformed
    case keyGenerated
    case keyStored
    case keyRetrieved
    case keyDeleted
    case biometricAuthenticationSucceeded
    case biometricAuthenticationFailed
    case passcodeAuthenticationSucceeded
    case passcodeAuthenticationFailed
    case dataStored
    case dataRetrieved
    case dataDeleted
    case sessionStarted
    case sessionEnded
    case sessionTimeout
    case securityLocked
    case securityUnlocked
    case securityValidationPerformed
    case securityViolationDetected
    
    var isCritical: Bool {
        switch self {
        case .securityViolationDetected:
            return true
        case .securityLocked:
            return true
        case .sessionTimeout:
            return true
        default:
            return false
        }
    }
    
    var severity: SecuritySeverity {
        switch self {
        case .securityViolationDetected:
            return .critical
        case .securityLocked:
            return .high
        case .sessionTimeout:
            return .medium
        case .biometricAuthenticationFailed, .passcodeAuthenticationFailed:
            return .medium
        default:
            return .low
        }
    }
}

// MARK: - Security Audit Report
struct SecurityAuditReport {
    let totalEvents: Int
    let recentEvents: Int
    let criticalEvents: Int
    let lastEvent: Date?
    let riskScore: Double
    
    var riskLevel: SecurityRiskLevel {
        switch riskScore {
        case 0.0..<0.2:
            return .low
        case 0.2..<0.5:
            return .medium
        case 0.5..<0.8:
            return .high
        default:
            return .critical
        }
    }
}

// MARK: - Supporting Classes (Simplified implementations)

class KeychainManager {
    private let configuration: SecurityConfiguration
    
    init(configuration: SecurityConfiguration) {
        self.configuration = configuration
    }
    
    func store<T: Codable>(_ item: T, identifier: String) throws {
        // Keychain storage implementation
    }
    
    func retrieve<T: Codable>(_ identifier: String) throws -> T? {
        // Keychain retrieval implementation
        return nil
    }
    
    func delete(identifier: String) throws {
        // Keychain deletion implementation
    }
    
    func validateIntegrity() -> Bool {
        // Keychain integrity validation
        return true
    }
    
    func clearSensitiveData() {
        // Clear sensitive data
    }
}

class EncryptionManager {
    private let configuration: SecurityConfiguration
    
    init(configuration: SecurityConfiguration) {
        self.configuration = configuration
    }
    
    func encrypt(_ data: Data, with key: SecurityKey) throws -> EncryptedData {
        // AES encryption implementation
        let key = SymmetricKey(data: key.data)
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        return EncryptedData(
            data: sealedBox.ciphertext,
            iv: sealedBox.nonce.withUnsafeBytes { Data($0) },
            keyId: key.id
        )
    }
    
    func decrypt(_ encryptedData: EncryptedData, with key: SecurityKey) throws -> Data {
        // AES decryption implementation
        let symmetricKey = SymmetricKey(data: key.data)
        let nonce = try AES.GCM.Nonce(data: encryptedData.iv)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: encryptedData.iv, tag: Data())
        
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }
    
    func generateKey() throws -> SecurityKey {
        let key = SymmetricKey(size: .bits256)
        return SecurityKey(data: key.withUnsafeBytes { Data($0) })
    }
    
    func validateIntegrity() -> Bool {
        return true
    }
    
    func clearSensitiveData() {
        // Clear sensitive data
    }
}

class BiometricManager {
    private let configuration: SecurityConfiguration
    
    init(configuration: SecurityConfiguration) {
        self.configuration = configuration
    }
    
    var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
}
