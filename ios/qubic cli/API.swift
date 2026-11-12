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

    // MARK: - Scripts

    private func authedRequest(path: String, method: String) throws -> URLRequest {
        guard !settings.baseURL.isEmpty, !settings.token.isEmpty,
              let url = URL(string: settings.baseURL.trimmingCharacters(in: .whitespaces) + path)
        else { throw APIError.notConfigured }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer " + settings.token, forHTTPHeaderField: "Authorization")
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest, decode: T.Type) async throws -> T {
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw APIError.network(error.localizedDescription) }
        guard let http = resp as? HTTPURLResponse else { throw APIError.network("no response") }
        if http.statusCode != 200 {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.decode(error.localizedDescription) }
    }

    func listScripts() async throws -> [ScriptMeta] {
        let req = try authedRequest(path: "/scripts", method: "GET")
        return try await send(req, decode: [ScriptMeta].self)
    }

    func getScript(name: String) async throws -> ScriptContent {
        let req = try authedRequest(path: "/scripts/" + name, method: "GET")
        return try await send(req, decode: ScriptContent.self)
    }

    struct OKResponse: Decodable { let ok: Bool }

    func saveScript(name: String, content: String) async throws {
        var req = try authedRequest(path: "/scripts/" + name, method: "PUT")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["content": content])
        _ = try await send(req, decode: OKResponse.self)
    }

    func deleteScript(name: String) async throws {
        let req = try authedRequest(path: "/scripts/" + name, method: "DELETE")
        _ = try await send(req, decode: OKResponse.self)
    }

    struct RunResponse: Decodable { let job_id: String }

    func runScript(name: String) async throws -> String {
        var req = try authedRequest(path: "/scripts/" + name + "/run", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = [:]
        if !settings.nodeIP.isEmpty   { body["nodeip"] = settings.nodeIP }
        if !settings.nodePort.isEmpty { body["nodeport"] = settings.nodePort }
        if !settings.seed.isEmpty     { body["seed"] = settings.seed }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(req, decode: RunResponse.self).job_id
    }

    func getJob(id: String, since: Int64 = 0) async throws -> JobStatus {
        let req = try authedRequest(path: "/jobs/" + id + "?since=\(since)", method: "GET")
        return try await send(req, decode: JobStatus.self)
    }

    func cancelJob(id: String) async throws {
        let req = try authedRequest(path: "/jobs/" + id + "/cancel", method: "POST")
        _ = try await send(req, decode: OKResponse.self)
    }

    func listJobs() async throws -> [JobSummary] {
        let req = try authedRequest(path: "/jobs", method: "GET")
        return try await send(req, decode: [JobSummary].self)
    }

    // MARK: - Script attachments

    func listAttachments(scriptName: String) async throws -> [AttachmentMeta] {
        let req = try authedRequest(path: "/scripts/" + scriptName + "/files", method: "GET")
        return try await send(req, decode: [AttachmentMeta].self)
    }

    struct AttachmentUploadResponse: Decodable { let name: String; let size: Int64 }

    func uploadAttachment(scriptName: String, data: Data, filename: String) async throws -> AttachmentUploadResponse {
        guard !settings.baseURL.isEmpty, !settings.token.isEmpty,
              let url = URL(string: settings.baseURL.trimmingCharacters(in: .whitespaces) + "/scripts/" + scriptName + "/files")
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

        return try await send(req, decode: AttachmentUploadResponse.self)
    }

    func deleteAttachment(scriptName: String, filename: String) async throws {
        let req = try authedRequest(path: "/scripts/" + scriptName + "/files/" + filename, method: "DELETE")
        _ = try await send(req, decode: OKResponse.self)
    }

    struct AttachmentContent: Decodable { let name: String; let content: String; let size: Int }

    func getAttachment(scriptName: String, filename: String) async throws -> AttachmentContent {
        let req = try authedRequest(path: "/scripts/" + scriptName + "/files/" + filename, method: "GET")
        return try await send(req, decode: AttachmentContent.self)
    }

    func saveAttachment(scriptName: String, filename: String, content: String) async throws {
        var req = try authedRequest(path: "/scripts/" + scriptName + "/files/" + filename, method: "PUT")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["content": content])
        _ = try await send(req, decode: OKResponse.self)
    }
}
