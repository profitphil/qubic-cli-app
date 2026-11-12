import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @State private var tokenField = ""
    @State private var healthStatus: String?
    @State private var healthOK: Bool?
    @State private var showingAddSeed = false

    var body: some View {
        Form {
            Section {
                TextField("https://…  or  http://100.x.x.x:8787", text: $settings.baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    SecureField("API token", text: $tokenField)
                    Button("Save") {
                        settings.token = tokenField
                        tokenField = ""
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.accent)
                    .disabled(tokenField.isEmpty)
                }
                if !settings.token.isEmpty {
                    Label("Token stored in Keychain", systemImage: "lock.fill")
                        .font(.caption).foregroundStyle(Theme.textDim)
                }
                Button {
                    Task { await testHealth() }
                } label: {
                    Label("Test connection", systemImage: "bolt.horizontal")
                }
                .buttonStyle(QGhostButtonStyle())
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

                if let s = healthStatus {
                    HStack(spacing: 6) {
                        if let ok = healthOK {
                            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundStyle(ok ? Theme.success : Theme.danger)
                        }
                        Text(s).font(.caption).foregroundStyle(Theme.text)
                    }
                }
            } header: {
                Text("Backend").foregroundStyle(Theme.textDim)
            }
            .listRowBackground(Theme.surface)

            Section {
                TextField("Node IP (optional)", text: $settings.nodeIP)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                TextField("Node port", text: $settings.nodePort)
                    .keyboardType(.numberPad)
            } header: {
                Text("Node").foregroundStyle(Theme.textDim)
            } footer: {
                Text("Auto-injected as -nodeip / -nodeport into every command.")
                    .font(.caption).foregroundStyle(Theme.textFaint)
            }
            .listRowBackground(Theme.surface)

            Section {
                if settings.seeds.isEmpty {
                    Text("No seeds saved")
                        .font(.caption).foregroundStyle(Theme.textDim)
                } else {
                    ForEach(settings.seeds) { entry in
                        SeedRow(entry: entry)
                    }
                }
                Button {
                    showingAddSeed = true
                } label: {
                    Label(
                        settings.seeds.isEmpty ? "Add seed" : "Add another seed (\(settings.seeds.count)/\(Settings.maxSeeds))",
                        systemImage: "plus.circle"
                    )
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.accent)
                .disabled(settings.seeds.count >= Settings.maxSeeds)
            } header: {
                Text("Seeds").foregroundStyle(Theme.textDim)
            } footer: {
                Text("Tap a row to activate it. The active seed is used for any command (or script) that signs a transaction. Anyone with your seed can drain your wallet — do not share.")
                    .font(.caption).foregroundStyle(Theme.textFaint)
            }
            .listRowBackground(Theme.surface)

            Section {
                NavigationLink {
                    AssetsManagerView()
                } label: {
                    Label("Manage assets", systemImage: "list.bullet.rectangle.fill")
                }
            } header: {
                Text("Assets").foregroundStyle(Theme.textDim)
            }
            .listRowBackground(Theme.surface)

            Section {
                LabeledContent("App") { Text("QubicApp 0.2").foregroundStyle(Theme.textDim) }
                LabeledContent("Backend") { Text("qubic-api remote").foregroundStyle(Theme.textDim) }
                Link(destination: URL(string: "https://github.com/qubic/qubic-cli")!) {
                    Label("qubic-cli on GitHub", systemImage: "arrow.up.right.square")
                        .foregroundStyle(Theme.accent)
                }
            } header: {
                Text("About").foregroundStyle(Theme.textDim)
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.base.ignoresSafeArea())
        .navigationTitle("Settings")
        .sheet(isPresented: $showingAddSeed) {
            AddSeedSheet().environmentObject(settings)
        }
    }

    private func testHealth() async {
        healthStatus = "Testing…"
        healthOK = nil
        let api = API(settings)
        do {
            let ok = try await api.health()
            healthOK = ok
            healthStatus = ok ? "Reachable" : "Not reachable"
        } catch {
            healthOK = false
            healthStatus = error.localizedDescription
        }
    }
}

struct SeedRow: View {
    @EnvironmentObject var settings: Settings
    let entry: SeedEntry
    @State private var labelDraft: String = ""
    @State private var editingLabel = false
    @State private var showValue = false
    @State private var confirmDelete = false

    private var isActive: Bool { settings.activeSeedId == entry.id }
    private var value: String { settings.seedValue(entry.id) }
    private var masked: String {
        guard !value.isEmpty else { return "(empty)" }
        return String(repeating: "•", count: max(0, value.count - 4)) + value.suffix(4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    settings.setActive(entry.id)
                } label: {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isActive ? Theme.accent : Theme.textDim)
                }
                .buttonStyle(.plain)

                if editingLabel {
                    TextField("Label", text: $labelDraft, onCommit: commitLabel)
                        .textInputAutocapitalization(.words)
                    Button("Done") { commitLabel() }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Theme.accent)
                } else {
                    Text(entry.label).font(.body).foregroundStyle(Theme.text)
                    Spacer()
                    Button {
                        labelDraft = entry.label
                        editingLabel = true
                    } label: {
                        Image(systemName: "pencil").foregroundStyle(Theme.textDim)
                    }
                    .buttonStyle(.plain)
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash").foregroundStyle(Theme.danger)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text(showValue ? value : masked)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    showValue.toggle()
                } label: {
                    Image(systemName: showValue ? "eye.slash" : "eye")
                        .foregroundStyle(Theme.textDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .alert("Delete \(entry.label)?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { settings.deleteSeed(entry.id) }
        } message: {
            Text("This removes the seed from this device. The wallet itself is unaffected.")
        }
    }

    private func commitLabel() {
        let trimmed = labelDraft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { settings.updateLabel(entry.id, label: trimmed) }
        editingLabel = false
    }
}

struct AddSeedSheet: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var seedField = ""
    @State private var showSeed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label (e.g. Main wallet)", text: $label)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                Section {
                    if showSeed {
                        TextField("55-char seed", text: $seedField)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("55-char seed", text: $seedField)
                    }
                    Toggle("Show seed while typing", isOn: $showSeed)
                } footer: {
                    Text("Stored in Keychain · device-only · locked.")
                        .font(.caption)
                }
            }
            .navigationTitle("Add seed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        settings.addSeed(label: label.trimmingCharacters(in: .whitespaces),
                                         value: seedField)
                        dismiss()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || seedField.count != 55)
                }
            }
        }
    }
}
