import Foundation

// MARK: - 專屬資料模型
struct SGLoginResponse: Codable { let access_token: String }
struct SGEventResponse: Codable { let data: [SGEventObject] }
struct SGAIStateResponse: Codable { let state: String; let count: Int? }

struct SGUserProfile: Codable {
    let id: Int; let role: String; let email: String?; let username: String?
    var displayName: String { return username ?? email ?? "Unknown User" }
}
struct SGUserListResponse: Codable { let status: String?; let data: [SGUserProfile] }

struct SGCleanupSettings: Codable { let retention_days: Int }
struct SGSettingsWrapper: Codable { let status: String?; let retention_days: Int? }

struct SGCurrentUser: Codable { let username: String; let role: String }

struct SGCameraConfig: Codable {
    var fire: Double; var smoke: Double; var fall: Double; var hardhat: Double
    var vest: Double; var smoking: Double; var phone: Double; var assignees: [String]
}

struct SGDeviceNode: Codable, Identifiable {
    let id: String; let type: String; let status: String?; let stream_url: String?; let name: String?
    var config: SGCameraConfig?
}

struct SGDeviceResponse: Codable { let status: String; let data: [SGDeviceNode] }

struct SGLoraParsedPayload: Codable {
    let device_id: String?
    let raw_type: String?
    let event_type: String?
    let event_name: String?
    let severity: String?
    let description: String?
    let mq2: String?
    let mq3: String?
}

struct SGLoraDownlinkResult: Codable {
    let sent: Bool?
    let reason: String?
    let error: String?
    let host: String?
    let port: Int?
    let topic: String?
    let command: String?
    let fPort: Int?
    let pending_kept: Bool?
}

struct SGLoraLatestResponse: Codable {
    let status: String
    let event: String?
    let event_id: Int?
    let dev_eui: String?
    let f_port: Int?
    let f_cnt: Int?
    let dr: Int?
    let payload_text: String?
    let parsed: SGLoraParsedPayload?
    let downlink: SGLoraDownlinkResult?
    let received_at: String?
    let message: String?
    
    var receivedDate: Date? {
        guard var string = received_at else { return nil }
        if !string.hasSuffix("Z") && !string.contains("+") { string += "Z" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

struct SGLoraDownlinkResponse: Codable {
    let status: String
    let downlink: SGLoraDownlinkResult?
    let message: String?
}

struct SGEventObject: Codable, Identifiable, Hashable {
    let id: Int; let event_name: String; let event_type: String; let severity: String; let description: String; let timestamp: String; let device_id: String?
    var parsedDate: Date {
        var string = timestamp; if !string.hasSuffix("Z") && !string.contains("+") { string += "Z" }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]; return formatter.date(from: string) ?? Date()
    }
    var localTimeString: String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"; formatter.timeZone = .current
        return formatter.string(from: parsedDate)
    }
}

// MARK: - API 客戶端
final class AISafeGuardAPIClient {
    static let shared = AISafeGuardAPIClient()
    
    private let baseURL = "http://127.0.0.1/api/v1"
    let chirpStackURL = URL(string: "http://127.0.0.1:8080")!
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpShouldUsePipelining = false
        return URLSession(configuration: config)
    }()
    
    private var token: String? {
        get { UserDefaults.standard.string(forKey: "aisafeguard_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "aisafeguard_access_token") }
    }
    
    private func makeRequest(endpoint: String, method: String = "GET", requiresAuth: Bool = true) throws -> URLRequest {
        guard let url = URL(string: baseURL + endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 10.0
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if requiresAuth {
            guard let validToken = token else { throw URLError(.userAuthenticationRequired) }
            request.setValue("Bearer \(validToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    // MARK: - 基礎與認證 API
    func login(username: String, password: String) async throws {
        var request = try makeRequest(endpoint: "/auth/login", method: "POST", requiresAuth: false)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyString = "username=\(username.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")&password=\(password.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")"
        request.httpBody = bodyString.data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        let loginRes = try JSONDecoder().decode(SGLoginResponse.self, from: data)
        self.token = loginRes.access_token
    }
    
    func fetchMe() async throws -> SGUserProfile {
        let request = try makeRequest(endpoint: "/users/me")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(SGUserProfile.self, from: data)
    }
    
    func fetchEvents() async throws -> [SGEventObject] {
        let request = try makeRequest(endpoint: "/events")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(SGEventResponse.self, from: data).data
    }
    
    func fetchAIState() async throws -> SGAIStateResponse {
        let request = try makeRequest(endpoint: "/analysis/current")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(SGAIStateResponse.self, from: data)
    }
    
    func resetSafety() async throws {
        let request = try makeRequest(endpoint: "/events/reset", method: "POST")
        let (_, _) = try await session.data(for: request)
    }
    
    func fetchCleanupSettings() async throws -> Int {
        let request = try makeRequest(endpoint: "/settings", method: "GET")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return 7 }
        let res = try JSONDecoder().decode(SGSettingsWrapper.self, from: data)
        return res.retention_days ?? 7
    }
    
    func updateCleanupSettings(days: Int) async throws {
        var request = try makeRequest(endpoint: "/settings", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["retention_days": days]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200...299).contains(httpResponse.statusCode) { throw URLError(.badServerResponse) }
    }
    
    func clearAllData() async throws {
        let request = try makeRequest(endpoint: "/events/clear", method: "DELETE")
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200...299).contains(httpResponse.statusCode) { throw URLError(.badServerResponse) }
    }
    
    func fetchAllUsers() async throws -> [SGUserProfile] {
        let request = try makeRequest(endpoint: "/users")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        do { return try JSONDecoder().decode(SGUserListResponse.self, from: data).data }
        catch { return try JSONDecoder().decode([SGUserProfile].self, from: data) }
    }
    
    func fetchCurrentUser() async throws -> SGCurrentUser {
        let request = try makeRequest(endpoint: "/users/me", method: "GET")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(SGCurrentUser.self, from: data)
    }
    
    func fetchDevices() async throws -> [SGDeviceNode] {
        let request = try makeRequest(endpoint: "/devices", method: "GET")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        let res = try JSONDecoder().decode(SGDeviceResponse.self, from: data)
        return res.data
    }
    
    func updateCameraConfig(cameraId: String, config: SGCameraConfig) async throws {
        var request = try makeRequest(endpoint: "/devices/\(cameraId)/config", method: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(config)
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
    }
    
    func fetchAssignableUsernames() async throws -> [String] {
        let request = try makeRequest(endpoint: "/users", method: "GET")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }
        do {
            let res = try JSONDecoder().decode(SGUserListResponse.self, from: data)
            return res.data.filter { $0.role.lowercased() != "admin" && $0.role.lowercased() != "super_admin" }.map { $0.displayName }
        } catch {
            do {
                let profiles = try JSONDecoder().decode([SGUserProfile].self, from: data)
                return profiles.filter { $0.role.lowercased() != "admin" && $0.role.lowercased() != "super_admin" }.map { $0.displayName }
            } catch { return [] }
        }
    }

    func fetchLoraLatest() async throws -> SGLoraLatestResponse {
        let request = try makeRequest(endpoint: "/lorawan/latest", method: "GET")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(SGLoraLatestResponse.self, from: data)
    }

    func sendLoraDownlink(command: String) async throws -> SGLoraDownlinkResponse {
        var request = try makeRequest(endpoint: "/lorawan/downlink", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["command": command])
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200...299).contains(httpResponse.statusCode) { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(SGLoraDownlinkResponse.self, from: data)
    }
    
    func addUser(account: String, role: String, password: String) async throws {
        var request = try makeRequest(endpoint: "/users", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["username": account, "password": password, "role": role.lowercased()]
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { throw URLError(.badServerResponse) }
    }
    
    func deleteUser(id: Int) async throws {
        let request = try makeRequest(endpoint: "/users/\(id)", method: "DELETE")
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { throw URLError(.badServerResponse) }
    }
    
    func callAIProxy(messages: [[String: String]]) async throws -> String {
        guard let url = URL(string: "http://127.0.0.1/ai-proxy") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["model": "qwen-plus", "messages": messages, "temperature": 0.7, "max_tokens": 200]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let choices = json["choices"] as? [[String: Any]], let message = choices.first?["message"] as? [String: Any], let content = message["content"] as? String { return content }
        return "AI Engine returned blank"
    }

    func sendNanoSystemCommand(command: String) async throws {
        let endpoint = "/devices/NANO-001/system_command"
        var request = try makeRequest(endpoint: endpoint, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["command": command]
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: data, encoding: .utf8) ?? "未知錯誤"
            print("🚨 遙控指令遭拒絕 [\(httpResponse.statusCode)]: \(errorMsg)")
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - 🚀 OTA 韌體與載荷中心 API
    struct SGOTAFile: Codable, Identifiable {
        var id: String { name ?? filename ?? UUID().uuidString }
        let name: String?
        let filename: String?
        let size: Int?
        let modified: Double?
        
        var displayName: String { return name ?? filename ?? "Unknown File" }
        var displaySize: String {
            guard let s = size else { return "Unknown Size" }
            if s > 1024 * 1024 { return String(format: "%.1f MB", Double(s) / (1024.0 * 1024.0)) }
            if s > 1024 { return String(format: "%.1f KB", Double(s) / 1024.0) }
            return "\(s) B"
        }
        var displayTime: String {
            guard let m = modified else { return "--" }
            let date = Date(timeIntervalSince1970: m)
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: date)
        }
    }

    struct SGOTAWrapper: Codable { let status: String?; let data: [SGOTAFile] }
    struct SGOTAContentResponse: Codable { let content: String }

    func fetchOTAFiles() async throws -> [SGOTAFile] {
        let request = try makeRequest(endpoint: "/ota/files", method: "GET")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        do { return try JSONDecoder().decode([SGOTAFile].self, from: data) }
        catch { return try JSONDecoder().decode(SGOTAWrapper.self, from: data).data }
    }

    func deleteOTAFile(filename: String) async throws {
        let request = try makeRequest(endpoint: "/ota/files/\(filename)", method: "DELETE")
        let (_, _) = try await session.data(for: request)
    }

    func deleteAllOTAFiles() async throws {
        let request = try makeRequest(endpoint: "/ota/files", method: "DELETE")
        let (_, _) = try await session.data(for: request)
    }

    func fetchOTAFileContent(filename: String) async throws -> String {
        let request = try makeRequest(endpoint: "/ota/files/\(filename)/content", method: "GET")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.badServerResponse) }
        if let res = try? JSONDecoder().decode(SGOTAContentResponse.self, from: data) { return res.content }
        return String(data: data, encoding: .utf8) ?? "Unable to decode content."
    }

    func uploadOTAFile(fileURL: URL) async throws {
        guard let token = token else { throw URLError(.userAuthenticationRequired) }
        guard let url = URL(string: baseURL + "/ota/upload") else { throw URLError(.badURL) }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let filename = fileURL.lastPathComponent
        let mimeType = "application/octet-stream"
        let fileData = try Data(contentsOf: fileURL)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { throw URLError(.badServerResponse) }
    }
    
    // MARK: - 📜 歷史日誌專屬 API (直連全新雲端 API)
    struct SGOTALog: Codable, Identifiable {
        let id: String
        let timestamp: String
        let status: String
        let message: String
    }
    
    func fetchOTALogs() async throws -> [SGOTALog] {
        // 🌟 加上 Cache-Buster 確保不會抓到手機的舊暫存
        let cacheBuster = Date().timeIntervalSince1970
        guard let url = URL(string: "http://127.0.0.1/ota-api/logs?_t=\(cacheBuster)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }
        do { return try JSONDecoder().decode([SGOTALog].self, from: data) } catch { return [] }
    }

    func addOTALog(status: String, message: String) async throws {
        guard let url = URL(string: "http://127.0.0.1/ota-api/logs") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["status": status, "message": message]
        request.httpBody = try JSONEncoder().encode(payload)
        let (_, _) = try await session.data(for: request)
    }

    func clearOTALogs() async throws {
        guard let url = URL(string: "http://127.0.0.1/ota-api/logs") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, _) = try await session.data(for: request)
    }
}
