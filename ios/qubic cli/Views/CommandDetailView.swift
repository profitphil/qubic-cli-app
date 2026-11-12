import SwiftUI
import UniformTypeIdentifiers

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
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        if command.readOnly { QBadge(text: "read", color: Theme.accent) }
                        if command.needsSeed { QBadge(text: "signs", color: Theme.warn) }
                        Spacer()
                    }
                    Text(command.flag)
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundStyle(Theme.text)
                    Text(command.description)
                        .font(.callout)
                        .foregroundStyle(Theme.textDim)
                }
                .padding(.vertical, 4)
                .listRowBackground(Theme.surface)
            }

            if command.needsSeed {
                Section {
                    Toggle("Use stored seed", isOn: $useStoredSeed)
                        .tint(Theme.accent)
                    if !useStoredSeed {
                        SecureField("55-char seed", text: Binding(
                            get: { values["__seed"] ?? "" },
                            set: { values["__seed"] = $0 }))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else if settings.seed.isEmpty {
                        Label("No seed stored — add one in Settings.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.danger).font(.caption)
                    } else {
                        Label("Using seed from Keychain", systemImage: "lock.fill")
                            .font(.caption).foregroundStyle(Theme.textDim)
                    }
                } header: {
                    Text("Seed").foregroundStyle(Theme.textDim)
                }
                .listRowBackground(Theme.surface)
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
                .listRowBackground(Theme.surface)
            }

            let pairDetected = AssetArgDetector.detect(command.args) != nil
            let otherArgs = command.args.filter { arg in
                if !pairDetected { return true }
                return !AssetArgDetector.isAssetNameArg(arg.name)
                    && !AssetArgDetector.isIssuerArg(arg.name)
            }
            if !otherArgs.isEmpty {
                Section {
                    ForEach(otherArgs, id: \.name) { arg in
                        ArgField(arg: arg, value: Binding(
                            get: { values[arg.name] ?? "" },
                            set: { values[arg.name] = $0 }))
                    }
                } header: {
                    Text("Arguments").foregroundStyle(Theme.textDim)
                }
                .listRowBackground(Theme.surface)
            }

            Section {
                Button(action: { runTapped() }) {
                    HStack(spacing: 8) {
                        if running { ProgressView().tint(Theme.base) }
                        Image(systemName: running ? "hourglass" : "play.fill")
                        Text(running ? "Running…" : (command.needsSeed ? "Review & Run" : "Run"))
                    }
                }
                .buttonStyle(QPrimaryButtonStyle(disabled: running || !canRun))
                .disabled(running || !canRun)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
            }

            if let result {
                Section {
                    ResultView(result: result)
                } header: {
                    Text("Result").foregroundStyle(Theme.textDim)
                }
                .listRowBackground(Theme.surface)
            }
            if let error {
                Section {
                    Label(error, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(Theme.danger)
                        .font(.system(.footnote, design: .monospaced))
                } header: {
                    Text("Error").foregroundStyle(Theme.textDim)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.base.ignoresSafeArea())
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
            let v = values[a.name] ?? ""
            // Allow empty string for `string` types — they may be a valid
            // "no input" value (e.g. INPUT_FORMAT_STRING). Also allow literal
            // "" which the run path normalizes to empty.
            if a.type == "string" { continue }
            if v.isEmpty { return false }
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
            var v = values[a.name] ?? ""
            // Treat literal "" (two quote chars) as an empty string. Users type
            // this to indicate "no input" for format-string args like
            // -invokecontractprocedure INPUT_FORMAT_STRING.
            if v == "\"\"" { v = "" }
            if a.type == "bool" {
                if v.lowercased() == "true" || v == "1" { continue } // flag-only booleans handled elsewhere
            }
            // Skip only OPTIONAL empty args. Required empties must still be
            // passed (as "") so positional arguments don't shift.
            if v.isEmpty && !a.required { continue }
            // Pass identities through as-is. The CLI deprecated hex format for
            // issuers and other hex-typed args; it now wants the 60-char Qubic
            // identity directly.
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(arg.name)
                    .font(.caption).bold()
                    .foregroundStyle(Theme.textDim)
                if arg.required {
                    Text("required").font(.caption2).foregroundStyle(Theme.accent)
                }
                Spacer()
                Text(arg.type.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.textFaint)
            }
            input
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(Theme.base.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
            if let hint = arg.hint, !hint.isEmpty {
                Text(hint).font(.caption2).foregroundStyle(Theme.textFaint)
            }
        }
        .padding(.vertical, 4)
    }

    private static let groupingFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()

    static func formatGrouped(_ digits: String) -> String {
        let clean = digits.filter(\.isNumber)
        guard !clean.isEmpty, let n = Decimal(string: clean) else { return clean }
        return groupingFormatter.string(from: n as NSDecimalNumber) ?? clean
    }

    @ViewBuilder
    private var input: some View {
        switch arg.type {
        case "number":
            GroupedNumberField(value: $value, placeholder: arg.name)
        case "tick":
            TextField(arg.name, text: $value)
                .keyboardType(.numberPad)
        case "address":
            HStack {
                TextField(arg.name, text: $value)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                AddressPickerButton(value: $value)
            }
        case "hex":
            HStack {
                TextField(arg.name, text: $value)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                AddressPickerButton(value: $value)
            }
        case "bool":
            Toggle("", isOn: Binding(
                get: { value == "true" },
                set: { value = $0 ? "true" : "false" }))
                .labelsHidden()
        case "file":
            FileArgInput(value: $value)
        default:
            TextField(arg.name, text: $value)
                .autocorrectionDisabled()
        }
    }
}

struct GroupedNumberField: View {
    @Binding var value: String
    let placeholder: String
    @State private var display: String = ""

    var body: some View {
        TextField(placeholder, text: $display)
            .keyboardType(.numberPad)
            .onAppear {
                display = ArgField.formatGrouped(value)
            }
            .onChange(of: display) { newDisplay in
                let digits = newDisplay.filter(\.isNumber)
                value = digits
                let formatted = ArgField.formatGrouped(digits)
                if formatted != newDisplay {
                    display = formatted
                }
            }
            .onChange(of: value) { newValue in
                let digits = newValue.filter(\.isNumber)
                let formatted = ArgField.formatGrouped(digits)
                if formatted != display {
                    display = formatted
                }
            }
    }
}

/// File-type arg: user taps "Choose file" → .fileImporter → uploads bytes to
/// backend /upload → stores the returned absolute path in `value` so the CLI
/// can read it. For commands that WRITE a file (e.g. -gettickdata) the user
/// can instead type a filename manually — it will be created in the backend
/// workdir and downloadable via /download/<name>.
struct FileArgInput: View {
    @Binding var value: String
    @EnvironmentObject var settings: Settings

    @State private var showPicker = false
    @State private var uploading = false
    @State private var uploadedName: String?
    @State private var uploadedSize: Int64 = 0
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    showPicker = true
                } label: {
                    HStack(spacing: 6) {
                        if uploading {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperclip")
                        }
                        Text(uploading ? "Uploading…" : "Choose file…")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.12))
                    .clipShape(Capsule())
                }
                .disabled(uploading)

                if !value.isEmpty {
                    Button {
                        value = ""
                        uploadedName = nil
                        uploadedSize = 0
                        error = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textDim)
                    }
                }
                Spacer()
            }

            if let name = uploadedName {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill").foregroundStyle(Theme.success).font(.caption)
                    Text(name).font(.caption).foregroundStyle(Theme.text)
                        .lineLimit(1).truncationMode(.middle)
                    Text(byteString(uploadedSize))
                        .font(.caption2).foregroundStyle(Theme.textFaint)
                }
            }

            TextField("…or type a filename (for output files)", text: $value)
                .font(.system(.caption, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(Theme.danger)
            }
        }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            Task { await handlePick(result) }
        }
    }

    private func handlePick(_ result: Result<[URL], Error>) async {
        error = nil
        do {
            guard let url = try result.get().first else { return }
            let started = url.startAccessingSecurityScopedResource()
            defer { if started { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            uploading = true
            defer { uploading = false }
            let api = API(settings)
            let resp = try await api.upload(data: data, filename: url.lastPathComponent)
            value = resp.path
            uploadedName = url.lastPathComponent
            uploadedSize = resp.size
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func byteString(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
}
