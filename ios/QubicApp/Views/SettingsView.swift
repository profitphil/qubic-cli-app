import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @State private var tokenField = ""
    @State private var seedField = ""
    @State private var showSeed = false
    @State private var healthStatus: String?

    var body: some View {
        Form {
            Section("Backend") {
                TextField("https://api.example.com", text: $settings.baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    SecureField("API token", text: $tokenField)
                    Button("Save") {
                        settings.token = tokenField
                        tokenField = ""
                    }.disabled(tokenField.isEmpty)
                }
                if !settings.token.isEmpty {
                    Text("Token stored in Keychain")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Test connection") {
                    Task { await testHealth() }
                }
                if let s = healthStatus {
                    Text(s).font(.caption)
                }
            }

            Section("Node") {
                TextField("Node IP (optional)", text: $settings.nodeIP)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                TextField("Node port", text: $settings.nodePort)
                    .keyboardType(.numberPad)
                Text("Auto-injected as -nodeip / -nodeport into every command.")
                    .font(.caption).foregroundStyle(.secondary)
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
                HStack {
                    Button("Save seed") {
                        settings.seed = seedField
                        seedField = ""
                    }.disabled(seedField.count != 55)
                    Spacer()
                    if !settings.seed.isEmpty {
                        Button("Clear", role: .destructive) {
                            settings.seed = ""
                        }
                    }
                }
                if !settings.seed.isEmpty {
                    Text("Seed stored in Keychain (device-only, locked)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("Seed")
            } footer: {
                Text("Stored in iOS Keychain. Used only when you run a command that signs a transaction. Anyone with your seed can drain your wallet — do not share.")
                    .font(.caption)
            }

            Section("Assets") {
                NavigationLink {
                    AssetsManagerView()
                } label: {
                    Label("Manage assets", systemImage: "list.bullet.rectangle")
                }
            }

            Section("About") {
                LabeledContent("qubic-cli", value: "remote")
                LabeledContent("App", value: "QubicApp 0.1")
                Link("Source (qubic-cli)", destination: URL(string: "https://github.com/qubic/qubic-cli")!)
            }
        }
        .navigationTitle("Settings")
    }

    private func testHealth() async {
        healthStatus = "Testing…"
        let api = API(settings)
        do {
            let ok = try await api.health()
            healthStatus = ok ? "✓ Reachable" : "✗ Not reachable"
        } catch {
            healthStatus = "✗ " + error.localizedDescription
        }
    }
}
