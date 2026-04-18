import Foundation

enum APIError: LocalizedError {
    case notConfigured, http(Int, String), decode(String), network(String)
    var errorDescription: String? {
        switch self {
        case .notConfigured:    return "Set API base URL and token in Settings."
        case .http(let c, let m): return "HTTP \(c): \(m)"
        case .decode(let m):    return "Decode: \(m)"
        case .network(let m):   return m
        }
    }
}

@MainActor
final class API {
    let settings: Settings
    init(_ settings: Settings) { self.settings = settings }

    func exec(args: [String], timeoutSec: Int = 60) async throws -> ExecResponse {
        guard !settings.baseURL.isEmpty, !settings.token.isEmpty,
              let url = URL(string: settings.baseURL.trimmingCharacters(in: .whitespaces) + "/exec")
        else { throw APIError.notConfigured }

        // auto-inject -nodeip / -nodeport if user set them and command didn't.
        // qubic-cli requires basic config BEFORE the command flag, so prepend.
        var finalArgs = args
        if !settings.nodePort.isEmpty, !finalArgs.contains("-nodeport") {
            finalArgs.insert(contentsOf: ["-nodeport", settings.nodePort], at: 0)
        }
        if !settings.nodeIP.isEmpty, !finalArgs.contains("-nodeip") {
            finalArgs.insert(contentsOf: ["-nodeip", settings.nodeIP], at: 0)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + settings.token, forHTTPHeaderField: "Authorization")
        req.timeoutInterval = TimeInterval(timeoutSec + 10)

        let body: [String: Any] = [
            "args": finalArgs,
            "timeout_sec": timeoutSec,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.network("no response")
        }
        if http.statusCode != 200 {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try JSONDecoder().decode(ExecResponse.self, from: data)
        } catch {
            throw APIError.decode(error.localizedDescription)
        }
    }

    struct UploadResponse: Decodable { let path: String; let name: String; let size: Int64 }

    func upload(data: Data, filename: String) async throws -> UploadResponse {
        guard !settings.baseURL.isEmpty, !settings.token.isEmpty,
              let url = URL(string: settings.baseURL.trimmingCharacters(in: .whitespaces) + "/upload")
        else { throw APIError.notConfigured }

        let boundary = "QubicBoundary-" + UUID().uuidString
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer " + settings.token, forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120

        let safeName = filename.replacingOccurrences(of: "\"", with: "")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (respData, resp): (Data, URLResponse)
        do {
            (respData, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
        guard let http = resp as? HTTPURLResponse else { throw APIError.network("no response") }
        if http.statusCode != 200 {
            throw APIError.http(http.statusCode, String(data: respData, encoding: .utf8) ?? "")
        }
        do {
            return try JSONDecoder().decode(UploadResponse.self, from: respData)
        } catch {
            throw APIError.decode(error.localizedDescription)
        }
    }

    func health() async throws -> Bool {
        guard let url = URL(string: settings.baseURL + "/healthz") else { return false }
        let (_, resp) = try await URLSession.shared.data(from: url)
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }
}
