import SwiftUI

/// Drop-in replacement for two separate text fields when a command has
/// both an ASSET_NAME arg and an ISSUER arg. Pick an asset → both fields fill.
struct AssetPickerSection: View {
    @EnvironmentObject var store: AssetsStore
    @Binding var assetName: String
    @Binding var issuer: String
    let assetArgName: String
    let issuerArgName: String

    @State private var showAddSheet = false
    @State private var showManualIssuer = false

    var body: some View {
        Section {
            if store.assets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No saved assets yet.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add an asset", systemImage: "plus.circle")
                    }
                }
            } else {
                Picker("Asset", selection: $assetName) {
                    Text("— select —").tag("")
                    ForEach(store.assets) { a in
                        Text(a.name).tag(a.name)
                    }
                }
                .onChange(of: assetName) { _, newName in
                    if let match = store.assets.first(where: { $0.name == newName }) {
                        issuer = match.issuer
                        showManualIssuer = false
                    }
                }

                if !assetName.isEmpty, let match = store.assets.first(where: { $0.name == assetName }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(issuerArgName).font(.caption).foregroundStyle(.secondary)
                        Text(match.issuer)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(1).truncationMode(.middle)
                        if let n = match.note, !n.isEmpty {
                            Text(n).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Button {
                    showAddSheet = true
                } label: {
                    Label("Add new asset…", systemImage: "plus").font(.footnote)
                }

                Toggle("Enter manually", isOn: $showManualIssuer)
                    .font(.footnote)

                if showManualIssuer {
                    TextField(assetArgName, text: $assetName)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField(issuerArgName, text: $issuer)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                }
            }
        } header: {
            Text("Asset")
        } footer: {
            Text("Pick an asset from your list — the issuer auto-fills. Manage your list in Settings → Assets.")
                .font(.caption)
        }
        .sheet(isPresented: $showAddSheet) {
            AddAssetSheet { name, iss, note in
                store.add(name: name, issuer: iss, note: note)
                assetName = name
                issuer = iss
            }
        }
    }
}

struct AddAssetSheet: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (String, String, String?) -> Void

    @State private var name = ""
    @State private var issuer = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Asset") {
                    TextField("Name (e.g. QX, CFB)", text: $name)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Issuer identity (60 chars)", text: $issuer)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("New Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, issuer, note.isEmpty ? nil : note)
                        dismiss()
                    }
                    .disabled(name.isEmpty || issuer.count != 60)
                }
            }
        }
    }
}

/// Full-screen asset manager for Settings.
struct AssetsManagerView: View {
    @EnvironmentObject var store: AssetsStore
    @State private var showAdd = false

    var body: some View {
        List {
            if store.assets.isEmpty {
                Text("No assets yet. Tap + to add one.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.assets) { a in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(a.name).font(.headline)
                        if a.custom {
                            Text("custom")
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    Text(a.issuer)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    if let n = a.note { Text(n).font(.caption2).foregroundStyle(.tertiary) }
                }
                .swipeActions {
                    if a.custom {
                        Button(role: .destructive) {
                            store.remove(a)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .navigationTitle("Assets")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAssetSheet { name, iss, note in
                store.add(name: name, issuer: iss, note: note)
            }
        }
    }
}
