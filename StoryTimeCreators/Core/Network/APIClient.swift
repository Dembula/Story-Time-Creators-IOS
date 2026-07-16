import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case forbidden
    case http(Int, String?)
    case decoding(String)
    case network(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid request URL."
        case .unauthorized: return "Please sign in again."
        case .forbidden: return "You do not have access to this resource."
        case .http(let code, let message):
            if let message, !message.isEmpty { return message }
            return "Request failed (\(code))."
        case .decoding(let detail): return "Could not read server response. \(detail)"
        case .network(let detail): return detail
        case .emptyResponse: return "Empty response from server."
        }
    }
}

struct APIClient {
    static let shared = APIClient()

    let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.httpCookieAcceptPolicy = .always
            config.httpShouldSetCookies = true
            config.httpCookieStorage = HTTPCookieStorage.shared
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 120
            self.session = URLSession(configuration: config)
        }

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let d = ISO8601DateFormatter.stFractional.date(from: raw)
                ?? ISO8601DateFormatter.st.date(from: raw) {
                return d
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(raw)")
        }

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func url(_ path: String, query: [URLQueryItem] = []) -> URL? {
        let cleaned = path.hasPrefix("/") ? path : "/\(path)"
        var components = URLComponents(string: AppConfig.apiBaseURL.absoluteString + cleaned)
        if !query.isEmpty {
            components?.queryItems = query
        }
        return components?.url
    }

    @discardableResult
    func request<T: Decodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        as type: T.Type = T.self
    ) async throws -> T {
        guard let url = url(path, query: query) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("StoryTimeCreators-iOS", forHTTPHeaderField: "User-Agent")

        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("Invalid response.")
        }

        if http.statusCode == 401 { throw APIError.unauthorized }
        if http.statusCode == 403 { throw APIError.forbidden }
        guard (200..<300).contains(http.statusCode) else {
            let message = Self.extractErrorMessage(from: data)
            throw APIError.http(http.statusCode, message)
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        if data.isEmpty {
            throw APIError.emptyResponse
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await request("GET", path: path, query: query)
    }

    func post<T: Decodable>(_ path: String, body: (any Encodable)? = nil) async throws -> T {
        try await request("POST", path: path, body: body)
    }

    func patch<T: Decodable>(_ path: String, body: (any Encodable)? = nil) async throws -> T {
        try await request("PATCH", path: path, body: body)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await request("DELETE", path: path)
    }

    func postForm(path: String, fields: [String: String]) async throws -> (Data, HTTPURLResponse) {
        guard let url = url(path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = fields
            .map { key, value in
                "\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
            }
            .joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("Invalid response.")
        }
        return (data, http)
    }

    func streamChat(path: String, body: some Encodable) async throws -> AsyncThrowingStream<String, Error> {
        guard let url = url(path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream, application/json, text/plain", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(AnyEncodable(body))

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("Invalid response.")
        }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, nil)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var buffer = ""
                    for try await line in bytes.lines {
                        if line.hasPrefix("data:") {
                            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                            if payload == "[DONE]" { break }
                            if let chunk = Self.parseSSEText(payload) {
                                continuation.yield(chunk)
                            } else if !payload.isEmpty {
                                continuation.yield(payload)
                            }
                        } else if !line.isEmpty && !line.hasPrefix(":") && !line.hasPrefix("event:") {
                            buffer += line
                            continuation.yield(line)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func parseSSEText(_ payload: String) -> String? {
        guard let data = payload.data(using: .utf8) else { return nil }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let text = obj["text"] as? String { return text }
            if let delta = obj["delta"] as? String { return delta }
            if let content = obj["content"] as? String { return content }
            if let choices = obj["choices"] as? [[String: Any]],
               let delta = choices.first?["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                return content
            }
        }
        return nil
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        return (obj["error"] as? String)
            ?? (obj["message"] as? String)
            ?? (obj["statusText"] as? String)
    }
}

struct EmptyResponse: Decodable {
    init() {}
}

private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: any Encodable) {
        encodeFunc = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

extension ISO8601DateFormatter {
    static let st: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let stFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
