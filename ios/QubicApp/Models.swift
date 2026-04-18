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
