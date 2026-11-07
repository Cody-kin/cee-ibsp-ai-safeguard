import Foundation

// MARK: - Models
struct EventResponse: Decodable {
    let data: [Event]
}

struct Event: Decodable, Identifiable {
    let id: Int
    let deviceId: String
    let eventType: String
    let eventName: String
    let severity: String
    let timestamp: String
    let description: String
    let hasImage: Bool
}

// MARK: - API Client
enum APIError: Error, LocalizedError {
    case invalidURL, unauthorized, decodingError, unknown
    case serverError(Int)
}

final class APIClient {
    static let shared = APIClient()
    
    let baseURL = "http://127.0.0.1/api/v1"
    let imageBaseURL = "http://127.0.0.1/storage"
    
    private init() {}
    
    // GET 請求
    func get<T: Decodable>(endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = UserDefaults.standard.string(forKey: "aisafeguard_access_token") ?? UserDefaults.standard.string(forKey: "jwt_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.unknown }
        
        if httpResponse.statusCode == 401 {
            NotificationCenter.default.post(name: NSNotification.Name("Unauthorized"), object: nil)
            throw APIError.unauthorized
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
    
    // POST 請求 (登入專用)
    func postFormURLEncoded<T: Decodable>(endpoint: String, body: [String: String]) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let formString = body.map { "\($0.key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")" }.joined(separator: "&")
        request.httpBody = formString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.unknown }
        
        if httpResponse.statusCode == 401 { throw APIError.unauthorized }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
    
    // DELETE 請求 (清除數據專用)
    func delete(endpoint: String) async throws {
        guard let url = URL(string: baseURL + endpoint) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let token = UserDefaults.standard.string(forKey: "aisafeguard_access_token") ?? UserDefaults.standard.string(forKey: "jwt_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.unknown }
        
        if httpResponse.statusCode == 401 {
            NotificationCenter.default.post(name: NSNotification.Name("Unauthorized"), object: nil)
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode == 403 {
            throw APIError.serverError(403) // 權限不足
        }
    }
}
