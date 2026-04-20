import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @State private var tokenField = ""
    @State private var seedField = ""
    @State private var showSeed = false
    @State private var healthStatus: String?
    @State private var healthOK: Bool?

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
                if showSeed {
                    TextField("55-char seed", text: $seedField)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } else {
                    SecureField("55-char seed", text: $seedField)
                }
                Toggle("Show seed while typing", isOn: $showSeed)
                    .tint(Theme.accent)
                HStack {
                    Button {
                        settings.seed = seedField
                        seedField = ""
                    } label: {
                        Label("Save seed", systemImage: "lock.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.accent)
                    .disabled(seedField.count != 55)

                    Spacer()

                    if !settings.seed.isEmpty {
                        Button(role: .destructive) {
                            settings.seed = ""
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                if !settings.seed.isEmpty {
                    Label("Stored in Keychain · device-only · locked",
                          systemImage: "lock.shield.fill")
                        .font(.caption).foregroundStyle(Theme.textDim)
                }
            } header: {
                Text("Seed").foregroundStyle(Theme.textDim)
            } footer: {
                Text("Used only when you run a command that signs a transaction. Anyone with your seed can drain your wallet — do not share.")
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
