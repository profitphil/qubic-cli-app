import Foundation

struct CommandArg: Codable, Hashable {
    let name: String
    let type: String          // string | number | address | tick | hex | file | bool
    let required: Bool
    var hint: String?
}

struct Command: Codable, Identifiable, Hashable {
    let flag: String
    let category: String
    let description: String
    let args: [CommandArg]
    let needsSeed: Bool
    let readOnly: Bool
    var id: String { flag }
}

struct CommandCategory: Codable, Identifiable, Hashable {
    let name: String
    let order: Int
    let icon: String
    var id: String { name }
}

struct ExecResponse: Codable {
    let stdout: String
    let stderr: String
    let exit_code: Int
    let duration_ms: Int
    let timed_out: Bool
}

struct ScriptMeta: Codable, Identifiable, Hashable {
    let name: String
    let size: Int64
    let lines: Int
    let updated_at: Int64
    var id: String { name }
}

struct ScriptContent: Codable {
    let name: String
    let content: String
}

struct AttachmentMeta: Codable, Identifiable, Hashable {
    let name: String
    let size: Int64
    let updated_at: Int64
    var id: String { name }
}

struct JobSummary: Codable, Identifiable, Hashable {
    let id: String
    let script: String
    let status: String
    let started_at: Int64
    let ended_at: Int64?
    let total_lines: Int
    let done_lines: Int
}

struct JobStatus: Codable {
    let id: String
    let script: String
    let status: String     // running | done | failed | canceled
    let started_at: Int64
    let ended_at: Int64?
    let total_lines: Int
    let done_lines: Int
    let last_error: String?
    let log_bytes: Int64
    let log_tail: String
    var isTerminal: Bool { status != "running" }
}
