import SwiftUI
import UniformTypeIdentifiers

struct FindReplaceBar: View {
    @Binding var text: String
    @Binding var visible: Bool
    @State private var find = ""
    @State private var replace = ""
    @State private var caseSensitive = false

    private var matchCount: Int {
        guard !find.isEmpty else { return 0 }
        let opts: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        var n = 0
        var range = text.startIndex..<text.endIndex
        while let r = text.range(of: find, options: opts, range: range) {
            n += 1
            range = r.upperBound..<text.endIndex
        }
        return n
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Find", text: $find)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Text("\(matchCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 28, alignment: .trailing)
                Button {
                    visible = false
                    find = ""; replace = ""
                } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                Image(systemName: "arrow.2.squarepath").foregroundColor(.secondary)
                TextField("Replace with", text: $replace)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Toggle("Aa", isOn: $caseSensitive)
                    .toggleStyle(.button)
                    .controlSize(.small)
                Button("Replace All") { replaceAll() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(find.isEmpty || matchCount == 0)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private func replaceAll() {
        guard !find.isEmpty else { return }
        let opts: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        text = text.replacingOccurrences(of: find, with: replace, options: opts)
    }
}

struct ScriptsView: View {
    @EnvironmentObject var settings: Settings
    @State private var scripts: [ScriptMeta] = []
    @State private var jobs: [JobSummary] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showingNew = false
    @State private var newName = ""

    var body: some View {
        List {
            if let error {
                Text(error).foregroundColor(.red).font(.footnote)
            }
            if !jobs.isEmpty {
                Section("Past runs") {
                    ForEach(jobs.prefix(20)) { j in
                        NavigationLink {
                            ScriptRunView(scriptName: j.script, jobId: j.id)
                        } label: {
                            JobSummaryRow(job: j)
                        }
                    }
                }
            }
            Section("Scripts") {
                ForEach(scripts) { script in
                    NavigationLink(value: script) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(script.name).font(.body.monospaced())
                            Text("\(script.lines) commands • \(formatDate(script.updated_at))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)

                if scripts.isEmpty && !loading {
                    Text("No scripts yet. Tap + to create one.")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Scripts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .refreshable { await load() }
        .navigationDestination(for: ScriptMeta.self) { meta in
            ScriptEditView(scriptName: meta.name)
        }
        .task { await load() }
        .alert("New script", isPresented: $showingNew) {
            TextField("name.txt", text: $newName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { newName = "" }
            Button("Create") {
                Task { await createNew() }
            }
        } message: {
            Text("Use letters, numbers, dot, dash, underscore. Must end in .txt")
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let api = API(settings)
            async let scriptsList = api.listScripts()
            async let jobsList = api.listJobs()
            scripts = try await scriptsList.sorted { $0.name < $1.name }
            jobs = try await jobsList.sorted { $0.started_at > $1.started_at }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func createNew() async {
        var n = newName.trimmingCharacters(in: .whitespaces)
        newName = ""
        if n.isEmpty { return }
        if !n.lowercased().hasSuffix(".txt") { n += ".txt" }
        do {
            let api = API(settings)
            try await api.saveScript(name: n, content: "")
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { scripts[$0].name }
        Task {
            let api = API(settings)
            for name in toDelete {
                try? await api.deleteScript(name: name)
            }
            await load()
        }
    }

    private func formatDate(_ ts: Int64) -> String {
        let d = Date(timeIntervalSince1970: TimeInterval(ts))
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }
}

struct ScriptEditView: View {
    @EnvironmentObject var settings: Settings
    let scriptName: String

    @State private var content = ""
    @State private var original = ""
    @State private var loading = true
    @State private var saving = false
    @State private var error: String?
    @State private var pendingJob: PendingJob?
    @State private var attachments: [AttachmentMeta] = []
    @State private var showingFilePicker = false
    @State private var uploading = false
    @State private var findVisible = false

    private struct PendingJob: Identifiable, Hashable { let id: String }

    private var dirty: Bool { content != original }

    var body: some View {
        VStack(spacing: 0) {
            if let error {
                Text(error).foregroundColor(.red).font(.footnote).padding(.horizontal)
            }
            if findVisible {
                FindReplaceBar(text: $content, visible: $findVisible)
            }
            TextEditor(text: $content)
                .font(.body.monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .overlay(alignment: .topLeading) {
                    if loading {
                        ProgressView().padding()
                    } else if content.isEmpty {
                        Text("One qubic-cli command per line.\nLines starting with # are comments.\nReference attached files by name (e.g. kc1.txt).\nUse chunk:<file> to auto-split a big file into 24-line pieces (e.g. chunk:wallets.txt).")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }

            attachmentsSection

            HStack {
                Button {
                    Task { await save() }
                } label: {
                    if saving { ProgressView() } else { Text("Save") }
                }
                .disabled(!dirty || saving)

                Spacer()

                Button {
                    Task { await run() }
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(dirty || saving)
            }
            .padding()
        }
        .navigationTitle(scriptName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { findVisible.toggle() } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
        .task {
            await load()
            await loadAttachments()
        }
        .navigationDestination(item: $pendingJob) { p in
            ScriptRunView(scriptName: scriptName, jobId: p.id)
        }
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            Task { await handlePick(result) }
        }
    }

    @ViewBuilder
    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Attachments").font(.caption.bold()).foregroundColor(.secondary)
                Spacer()
                Button {
                    showingFilePicker = true
                } label: {
                    if uploading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "plus.circle")
                    }
                }
                .disabled(uploading)
            }
            if attachments.isEmpty {
                Text("No files attached")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(attachments) { a in
                    HStack {
                        NavigationLink {
                            AttachmentEditView(scriptName: scriptName, filename: a.name)
                        } label: {
                            HStack {
                                Image(systemName: "doc")
                                Text(a.name).font(.footnote.monospaced())
                                Spacer()
                                Text(byteString(a.size)).font(.caption).foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            Task { await deleteAttachment(a.name) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private func byteString(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }

    private func load() async {
        do {
            let api = API(settings)
            let c = try await api.getScript(name: scriptName)
            content = c.content
            original = c.content
            loading = false
        } catch {
            self.error = error.localizedDescription
            loading = false
        }
    }

    private func loadAttachments() async {
        do {
            let api = API(settings)
            attachments = try await api.listAttachments(scriptName: scriptName).sorted { $0.name < $1.name }
        } catch {
            // attachments are optional; don't surface error if script is brand new
        }
    }

    private func handlePick(_ result: Result<[URL], Error>) async {
        guard let urls = try? result.get(), !urls.isEmpty else { return }
        uploading = true
        defer { uploading = false }
        let api = API(settings)
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else {
                error = "Couldn't access \(url.lastPathComponent)."
                continue
            }
            do {
                let data = try Data(contentsOf: url)
                _ = try await api.uploadAttachment(scriptName: scriptName, data: data, filename: url.lastPathComponent)
            } catch {
                self.error = error.localizedDescription
            }
            url.stopAccessingSecurityScopedResource()
        }
        await loadAttachments()
    }

    private func deleteAttachment(_ name: String) async {
        do {
            let api = API(settings)
            try await api.deleteAttachment(scriptName: scriptName, filename: name)
            await loadAttachments()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            let api = API(settings)
            try await api.saveScript(name: scriptName, content: content)
            original = content
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func run() async {
        do {
            let api = API(settings)
            let id = try await api.runScript(name: scriptName)
            pendingJob = PendingJob(id: id)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ScriptRunView: View {
    @EnvironmentObject var settings: Settings
    let scriptName: String
    let jobId: String

    @State private var job: JobStatus?
    @State private var log = ""
    @State private var error: String?
    @State private var pollTask: Task<Void, Never>?
    @State private var canceling = false

    private var txHashes: [String] {
        log.split(separator: "\n").compactMap { line in
            let s = String(line)
            guard s.hasPrefix("TXHASH:") else { return nil }
            return s.dropFirst("TXHASH:".count).trimmingCharacters(in: .whitespaces)
        }
    }

    private var txExplorerLinks: [String] {
        txHashes.map { "https://explorer.qubic.org/network/tx/" + $0 }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if let job {
                        progressHeader(job)
                    }
                    Text(log.isEmpty ? "Waiting for output…" : log)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .id("logbottom")
                }
                .padding(.vertical)
            }
            .onChange(of: log) { _, _ in
                withAnimation { proxy.scrollTo("logbottom", anchor: .bottom) }
            }
        }
        .navigationTitle(scriptName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let job, !job.isTerminal {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel", role: .destructive) {
                        Task { await cancel() }
                    }
                    .disabled(canceling)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if !txHashes.isEmpty {
                        Button {
                            UIPasteboard.general.string = txExplorerLinks.joined(separator: "\n")
                        } label: {
                            Label("Copy explorer links (\(txHashes.count))", systemImage: "link")
                        }
                        ShareLink(item: txExplorerLinks.joined(separator: "\n"),
                                  preview: SharePreview("\(scriptName) — explorer links")) {
                            Label("Share explorer links", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button {
                            UIPasteboard.general.string = txHashes.joined(separator: "\n")
                        } label: {
                            Label("Copy TxHashes (raw)", systemImage: "doc.on.doc")
                        }
                        Divider()
                    }
                    Button {
                        UIPasteboard.general.string = log
                    } label: {
                        Label("Copy full log", systemImage: "doc.text")
                    }
                    if !log.isEmpty {
                        ShareLink(item: log,
                                  preview: SharePreview("\(scriptName) — log")) {
                            Label("Share full log", systemImage: "square.and.arrow.up.on.square")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(log.isEmpty && txHashes.isEmpty)
            }
        }
        .task { startPolling() }
        .onDisappear { pollTask?.cancel() }
    }

    @ViewBuilder
    private func progressHeader(_ j: JobStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                statusBadge(j.status)
                Text("\(j.done_lines) / \(j.total_lines)")
                    .font(.subheadline.monospacedDigit())
                Spacer()
            }
            ProgressView(value: Double(j.done_lines), total: Double(max(j.total_lines, 1)))
            if let err = j.last_error, !err.isEmpty {
                Text(err).font(.caption).foregroundColor(.orange)
            }
            if let error {
                Text(error).font(.caption).foregroundColor(.red)
            }
        }
        .padding(.horizontal)
    }

    private func statusBadge(_ status: String) -> some View {
        let color: Color = {
            switch status {
            case "running":  return .blue
            case "done":     return .green
            case "failed":   return .red
            case "canceled": return .orange
            default:         return .secondary
            }
        }()
        return Text(status.uppercased())
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            let api = API(settings)
            var since: Int64 = 0
            while !Task.isCancelled {
                do {
                    let j = try await api.getJob(id: jobId, since: since)
                    job = j
                    if !j.log_tail.isEmpty {
                        log += j.log_tail
                        since = j.log_bytes
                    }
                    if j.isTerminal { break }
                } catch {
                    self.error = error.localizedDescription
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    private func cancel() async {
        canceling = true
        defer { canceling = false }
        do {
            let api = API(settings)
            try await api.cancelJob(id: jobId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct AttachmentEditView: View {
    @EnvironmentObject var settings: Settings
    let scriptName: String
    let filename: String

    @State private var content = ""
    @State private var original = ""
    @State private var loading = true
    @State private var saving = false
    @State private var error: String?
    @State private var findVisible = false

    private var dirty: Bool { content != original }

    var body: some View {
        VStack(spacing: 0) {
            if let error {
                Text(error).foregroundColor(.red).font(.footnote).padding(.horizontal)
            }
            if findVisible {
                FindReplaceBar(text: $content, visible: $findVisible)
            }
            TextEditor(text: $content)
                .font(.body.monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .overlay(alignment: .topLeading) {
                    if loading {
                        ProgressView().padding()
                    }
                }
            HStack {
                Button {
                    Task { await save() }
                } label: {
                    if saving { ProgressView() } else { Text("Save") }
                }
                .disabled(!dirty || saving)
                Spacer()
                Text("\(content.count) chars").font(.caption).foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle(filename)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { findVisible.toggle() } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            let api = API(settings)
            let c = try await api.getAttachment(scriptName: scriptName, filename: filename)
            content = c.content
            original = c.content
            loading = false
        } catch {
            self.error = error.localizedDescription
            loading = false
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            let api = API(settings)
            try await api.saveAttachment(scriptName: scriptName, filename: filename, content: content)
            original = content
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct JobSummaryRow: View {
    let job: JobSummary

    var body: some View {
        HStack(spacing: 8) {
            statusDot
            VStack(alignment: .leading, spacing: 2) {
                Text(job.script).font(.body.monospaced())
                HStack(spacing: 6) {
                    Text("\(job.done_lines)/\(job.total_lines)")
                    Text("•")
                    Text(Date(timeIntervalSince1970: TimeInterval(job.started_at)), style: .relative)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch job.status {
        case "running":  return .blue
        case "done":     return .green
        case "failed":   return .red
        case "canceled": return .orange
        default:         return .gray
        }
    }
}
