import SwiftUI

struct CommandDetailView: View {
    let command: Command
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var history: History
    @EnvironmentObject var assetsStore: AssetsStore

    @State private var values: [String: String] = [:]
    @State private var running = false
    @State private var result: ExecResponse?
    @State private var error: String?
    @State private var showConfirm = false
    @State private var useStoredSeed = true

    var body: some View {
        Form {
            Section {
                Text(command.description).font(.callout)
                HStack {
                    Text(command.flag).font(.system(.caption, design: .monospaced))
                    Spacer()
                    if command.readOnly { badge("read-only", .blue) }
                    if command.needsSeed { badge("signs tx", .orange) }
                }
            }

            if command.needsSeed {
                Section("Seed") {
                    Toggle("Use stored seed", isOn: $useStoredSeed)
                    if !useStoredSeed {
                        SecureField("55-char seed", text: Binding(
                            get: { values["__seed"] ?? "" },
                            set: { values["__seed"] = $0 }))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else if settings.seed.isEmpty {
                        Text("No seed stored. Add one in Settings.")
                            .foregroundStyle(.red).font(.caption)
                    } else {
                        Text("Using seed from Keychain").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if let (assetArg, issuerArg) = AssetArgDetector.detect(command.args) {
                AssetPickerSection(
                    assetName: Binding(
                        get: { values[assetArg] ?? "" },
                        set: { values[assetArg] = $0 }),
                    issuer: Binding(
                        get: { values[issuerArg] ?? "" },
                        set: { values[issuerArg] = $0 }),
                    assetArgName: assetArg,
                    issuerArgName: issuerArg)
            }

            let pairDetected = AssetArgDetector.detect(command.args) != nil
            let otherArgs = command.args.filter { arg in
                if !pairDetected { return true }
                return !AssetArgDetector.isAssetNameArg(arg.name)
                    && !AssetArgDetector.isIssuerArg(arg.name)
            }
            if !otherArgs.isEmpty {
                Section("Arguments") {
                    ForEach(otherArgs, id: \.name) { arg in
                        ArgField(arg: arg, value: Binding(
                            get: { values[arg.name] ?? "" },
                            set: { values[arg.name] = $0 }))
                    }
                }
            }

            Section {
                Button(action: { runTapped() }) {
                    HStack {
                        Spacer()
                        if running { ProgressView().padding(.trailing, 6) }
                        Text(running ? "Running…" : (command.needsSeed ? "Review & Run" : "Run"))
                            .bold()
                        Spacer()
                    }
                }
                .disabled(running || !canRun)
            }

            if let result {
                Section("Result") {
                    ResultView(result: result)
                }
            }
            if let error {
                Section("Error") {
                    Text(error).foregroundStyle(.red).font(.system(.footnote, design: .monospaced))
                }
            }
        }
        .navigationTitle(command.flag)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    history.toggleFavorite(command.flag)
                } label: {
                    Image(systemName: history.isFavorite(command.flag) ? "star.fill" : "star")
                }
            }
        }
        .confirmationDialog(confirmMessage, isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Run", role: .destructive) { Task { await run() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var canRun: Bool {
        for a in command.args where a.required {
            if (values[a.name] ?? "").isEmpty { return false }
        }
        return true
    }

    private var confirmMessage: String {
        "This will sign and submit a transaction via qubic-cli \(command.flag). Proceed?"
    }

    private func runTapped() {
        error = nil
        result = nil
        if command.needsSeed && !command.readOnly {
            showConfirm = true
        } else {
            Task { await run() }
        }
    }

    private func run() async {
        running = true
        defer { running = false }
        var args: [String] = [command.flag]
        for a in command.args {
            let v = values[a.name] ?? ""
            if v.isEmpty { continue }
            if a.type == "bool" {
                if v.lowercased() == "true" || v == "1" { continue } // flag-only booleans handled elsewhere
            }
            args.append(v)
        }
        if command.needsSeed {
            let seed = useStoredSeed ? settings.seed : (values["__seed"] ?? "")
            if !seed.isEmpty { args.insert(contentsOf: ["-seed", seed], at: 0) }
        }
        do {
            let api = API(settings)
            let resp = try await api.exec(args: args, timeoutSec: 60)
            result = resp
            history.record(flag: command.flag, args: args, response: resp)
        } catch {
            self.error = error.localizedDescription
        }
    }

    @ViewBuilder
    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct ArgField: View {
    let arg: CommandArg
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(arg.name).font(.caption).foregroundStyle(.secondary)
                if arg.required { Text("*").foregroundStyle(.red).font(.caption) }
                Spacer()
                Text(arg.type).font(.caption2).foregroundStyle(.tertiary)
            }
            input
            if let hint = arg.hint, !hint.isEmpty {
                Text(hint).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var input: some View {
        switch arg.type {
        case "number", "tick":
            TextField(arg.name, text: $value)
                .keyboardType(.numberPad)
        case "address":
            TextField(arg.name, text: $value)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
        case "hex":
            TextField(arg.name, text: $value)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
        case "bool":
            Toggle("", isOn: Binding(
                get: { value == "true" },
                set: { value = $0 ? "true" : "false" }))
                .labelsHidden()
        default:
            TextField(arg.name, text: $value)
                .autocorrectionDisabled()
        }
    }
}
