import Foundation
import Combine
import Network

// MARK: - Network Manager
class NetworkManager {
    // MARK: - Properties
    private let configuration: NetworkConfiguration
    private let session: URLSession
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Publishers
    private var networkStateSubject = CurrentValueSubject<NetworkState, Never>(.connected)
    var networkStatePublisher: AnyPublisher<NetworkState, Never> {
        networkStateSubject.eraseToAnyPublisher()
    }
    
    private var connectivitySubject = PassthroughSubject<ConnectivityInfo, Never>()
    var connectivityPublisher: AnyPublisher<ConnectivityInfo, Never> {
        connectivitySubject.eraseToAnyPublisher()
    }
    
    // MARK: - State
    private var isNetworkAvailable = true
    private var currentNetworkType: NetworkType = .unknown
    
    // MARK: - Initialization
    init(configuration: NetworkConfiguration) {
        self.configuration = configuration
        self.session = URLSession(configuration: createSessionConfiguration())
        self.monitor = NWPathMonitor()
        
        setupNetworkMonitoring()
        setupPerformanceMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Public Methods
    func request<T: Codable>(_ endpoint: APIEndpoint<T>) -> AnyPublisher<T, NetworkError> {
        guard isNetworkAvailable else {
            return Fail(error: NetworkError.noConnection)
                .eraseToAnyPublisher()
        }
        
        do {
            let request = try createURLRequest(from: endpoint)
            
            return session.dataTaskPublisher(for: request)
                .tryMap { data, response -> Data in
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw NetworkError.invalidResponse
                    }
                    
                    guard 200...299 ~= httpResponse.statusCode else {
                        throw NetworkError.serverError(httpResponse.statusCode)
                    }
                    
                    return data
                }
                .decode(type: T.self, decoder: JSONDecoder())
                .mapError { error in
                    if error is DecodingError {
                        return NetworkError.decodingError
                    } else if let networkError = error as? NetworkError {
                        return networkError
                    } else {
                        return NetworkError.unknown(error)
                    }
                }
                .retry(configuration.retryCount)
                .timeout(.seconds(configuration.timeout), scheduler: DispatchQueue.main)
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error as? NetworkError ?? NetworkError.unknown(error))
                .eraseToAnyPublisher()
        }
    }
    
    func upload<T: Codable>(_ endpoint: APIEndpoint<T>, data: Data) -> AnyPublisher<T, NetworkError> {
        guard isNetworkAvailable else {
            return Fail(error: NetworkError.noConnection)
                .eraseToAnyPublisher()
        }
        
        do {
            var request = try createURLRequest(from: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            return session.dataTaskPublisher(for: request)
                .tryMap { data, response -> Data in
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw NetworkError.invalidResponse
                    }
                    
                    guard 200...299 ~= httpResponse.statusCode else {
                        throw NetworkError.serverError(httpResponse.statusCode)
                    }
                    
                    return data
                }
                .decode(type: T.self, decoder: JSONDecoder())
                .mapError { error in
                    if error is DecodingError {
                        return NetworkError.decodingError
                    } else if let networkError = error as? NetworkError {
                        return networkError
                    } else {
                        return NetworkError.unknown(error)
                    }
                }
                .retry(configuration.retryCount)
                .timeout(.seconds(configuration.timeout), scheduler: DispatchQueue.main)
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error as? NetworkError ?? NetworkError.unknown(error))
                .eraseToAnyPublisher()
        }
    }
    
    func download(from url: URL, progress: @escaping (Double) -> Void) -> AnyPublisher<URL, NetworkError> {
        guard isNetworkAvailable else {
            return Fail(error: NetworkError.noConnection)
                .eraseToAnyPublisher()
        }
        
        let request = URLRequest(url: url)
        
        return session.downloadTaskPublisher(for: request)
            .tryMap { url, response -> URL in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw NetworkError.serverError(httpResponse.statusCode)
                }
                
                return url
            }
            .mapError { error in
                if let networkError = error as? NetworkError {
                    return networkError
                } else {
                    return NetworkError.unknown(error)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func updateConfiguration(_ newConfig: NetworkConfiguration) {
        // Update configuration dynamically
        // This would require recreating the session with new config
    }
    
    func shutdown() {
        monitor.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Private Methods
    private func createSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeout
        config.timeoutIntervalForResource = configuration.timeout * 2
        config.requestCachePolicy = configuration.cachePolicy
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024, // 50MB
            diskCapacity: 200 * 1024 * 1024,  // 200MB
            diskPath: nil
        )
        
        if configuration.enableLogging {
            config.protocolClasses = [NetworkLoggingProtocol.self]
        }
        
        return config
    }
    
    private func createURLRequest<T: Codable>(from endpoint: APIEndpoint<T>) throws -> URLRequest {
        let url = configuration.baseURL.appendingPathComponent(endpoint.path)
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add authentication headers if needed
        if let authToken = endpoint.authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Add custom headers
        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body if present
        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        return request
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkChange(path)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func handleNetworkChange(_ path: NWPath) {
        let previousState = networkStateSubject.value
        
        if path.status == .satisfied {
            isNetworkAvailable = true
            currentNetworkType = NetworkType.from(path)
            networkStateSubject.send(.connected)
        } else {
            isNetworkAvailable = false
            currentNetworkType = .unknown
            networkStateSubject.send(.disconnected)
        }
        
        let connectivityInfo = ConnectivityInfo(
            isConnected: path.status == .satisfied,
            networkType: currentNetworkType,
            connectionQuality: calculateConnectionQuality(path),
            timestamp: Date()
        )
        
        connectivitySubject.send(connectivityInfo)
        
        // Log network changes
        if configuration.enableLogging {
            NetworkLogger.shared.logNetworkChange(
                from: previousState,
                to: networkStateSubject.value,
                connectivity: connectivityInfo
            )
        }
    }
    
    private func calculateConnectionQuality(_ path: NWPath) -> ConnectionQuality {
        guard path.status == .satisfied else {
            return .poor
        }
        
        let isExpensive = path.isExpensive
        let hasConstrainedPath = path.isConstrained
        
        if isExpensive || hasConstrainedPath {
            return .poor
        }
        
        switch currentNetworkType {
        case .wifi:
            return .excellent
        case .cellular:
            return .good
        case .wired:
            return .excellent
        case .other:
            return .fair
        case .unknown:
            return .poor
        }
    }
    
    private func setupPerformanceMonitoring() {
        // Setup network performance monitoring
        NetworkPerformanceMonitor.shared.configure(with: configuration)
    }
}

// MARK: - Network State
enum NetworkState {
    case connected
    case disconnected
    case connecting
    case limited
    
    var isConnected: Bool {
        switch self {
        case .connected:
            return true
        default:
            return false
        }
    }
}

// MARK: - Network Type
enum NetworkType {
    case wifi
    case cellular
    case wired
    case other
    case unknown
    
    static func from(_ path: NWPath) -> NetworkType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        } else if path.usesInterfaceType(.other) {
            return .other
        } else {
            return .unknown
        }
    }
}

// MARK: - Connection Quality
enum ConnectionQuality {
    case excellent
    case good
    case fair
    case poor
    
    var speedMultiplier: Double {
        switch self {
        case .excellent:
            return 1.0
        case .good:
            return 0.8
        case .fair:
            return 0.6
        case .poor:
            return 0.3
        }
    }
}

// MARK: - Connectivity Info
struct ConnectivityInfo {
    let isConnected: Bool
    let networkType: NetworkType
    let connectionQuality: ConnectionQuality
    let timestamp: Date
}

// MARK: - API Endpoint
struct APIEndpoint<T: Codable> {
    let path: String
    let method: HTTPMethod
    let body: T?
    let headers: [String: String]
    let authToken: String?
    
    init(path: String, method: HTTPMethod = .GET, body: T? = nil, headers: [String: String] = [:], authToken: String? = nil) {
        self.path = path
        self.method = method
        self.body = body
        self.headers = headers
        self.authToken = authToken
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Network Error
enum NetworkError: LocalizedError {
    case noConnection
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError
    case timeout
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .timeout:
            return "Request timed out"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Network Logging Protocol
class NetworkLoggingProtocol: URLProtocol {
    static var requestCount = 0
    static var responseCount = 0
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        Self.requestCount += 1
        NetworkLogger.shared.logRequest(request)
        
        let dataTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let data = data, let response = response {
                self?.client?.urlProtocol(self, didReceive: data, cacheStoragePolicy: .notAllowed)
                self?.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                Self.responseCount += 1
                NetworkLogger.shared.logResponse(response, data: data, error: error)
            } else if let error = error {
                self?.client?.urlProtocol(self, didFailWithError: error)
                NetworkLogger.shared.logError(error)
            }
            
            self?.client?.urlProtocolDidFinishLoading(self)
        }
        
        dataTask.resume()
    }
    
    override func stopLoading() {
        // Handle cleanup
    }
}

// MARK: - Network Logger
class NetworkLogger {
    static let shared = NetworkLogger()
    private init() {}
    
    func logRequest(_ request: URLRequest) {
        guard let url = request.url else { return }
        print("🌐 [REQUEST] \(request.httpMethod ?? "GET") \(url.absoluteString)")
        
        if let headers = request.allHTTPHeaderFields {
            print("📋 Headers: \(headers)")
        }
        
        if let body = request.httpBody {
            print("📦 Body: \(String(data: body, encoding: .utf8) ?? "Non-text data")")
        }
    }
    
    func logResponse(_ response: URLResponse, data: Data?, error: Error?) {
        print("📡 [RESPONSE] \(response.url?.absoluteString ?? "Unknown URL")")
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Status: \(httpResponse.statusCode)")
        }
        
        if let data = data {
            print("📦 Data: \(data.count) bytes")
        }
        
        if let error = error {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
    
    func logError(_ error: Error) {
        print("❌ [ERROR] \(error.localizedDescription)")
    }
    
    func logNetworkChange(from previous: NetworkState, to current: NetworkState, connectivity: ConnectivityInfo) {
        print("🔄 [NETWORK] \(previous) → \(current)")
        print("📊 Type: \(connectivity.networkType), Quality: \(connectivity.connectionQuality)")
    }
}

// MARK: - Network Performance Monitor
class NetworkPerformanceMonitor {
    static let shared = NetworkPerformanceMonitor()
    private var metrics: [NetworkMetric] = []
    private let queue = DispatchQueue(label: "NetworkPerformance", qos: .utility)
    
    private init() {}
    
    func configure(with configuration: NetworkConfiguration) {
        // Setup performance monitoring
    }
    
    func recordMetric(_ metric: NetworkMetric) {
        queue.async {
            self.metrics.append(metric)
            
            // Keep only last 1000 metrics
            if self.metrics.count > 1000 {
                self.metrics.removeFirst(self.metrics.count - 1000)
            }
        }
    }
    
    func getAverageResponseTime() -> TimeInterval {
        return queue.sync {
            let recentMetrics = metrics.suffix(100)
            guard !recentMetrics.isEmpty else { return 0 }
            
            let totalTime = recentMetrics.reduce(0) { $0 + $1.responseTime }
            return totalTime / TimeInterval(recentMetrics.count)
        }
    }
    
    func getSuccessRate() -> Double {
        return queue.sync {
            let recentMetrics = metrics.suffix(100)
            guard !recentMetrics.isEmpty else { return 0 }
            
            let successfulMetrics = recentMetrics.filter { $0.isSuccess }
            return Double(successfulMetrics.count) / Double(recentMetrics.count)
        }
    }
}

// MARK: - Network Metric
struct NetworkMetric {
    let url: URL
    let method: String
    let responseTime: TimeInterval
    let statusCode: Int?
    let dataSize: Int
    let timestamp: Date
    let isSuccess: Bool
    
    init(url: URL, method: String, responseTime: TimeInterval, statusCode: Int?, dataSize: Int, timestamp: Date = Date()) {
        self.url = url
        self.method = method
        self.responseTime = responseTime
        self.statusCode = statusCode
        self.dataSize = dataSize
        self.timestamp = timestamp
        self.isSuccess = statusCode.map { 200...299 ~= $0 } ?? false
    }
}
