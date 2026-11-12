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
                        .foregroundStyle(Theme.textDim)
                        .font(.footnote)
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add an asset", systemImage: "plus.circle")
                            .foregroundStyle(Theme.accent)
                    }
                }
            } else {
                Picker("Asset", selection: $assetName) {
                    Text("— select —").tag("")
                    ForEach(store.assets) { a in
                        Text(a.name).tag(a.name)
                    }
                }
                .tint(Theme.accent)
                .onChange(of: assetName) { _, newName in
                    if let match = store.assets.first(where: { $0.name == newName }) {
                        issuer = match.issuer
                        showManualIssuer = false
                    }
                }

                if !assetName.isEmpty, let match = store.assets.first(where: { $0.name == assetName }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(issuerArgName)
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.textDim)
                        Text(match.issuer)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .textSelection(.enabled)
                            .lineLimit(1).truncationMode(.middle)
                        if let n = match.note, !n.isEmpty {
                            Text(n).font(.caption2).foregroundStyle(Theme.textFaint)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.base.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                }

                Button {
                    showAddSheet = true
                } label: {
                    Label("Add new asset…", systemImage: "plus")
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                }

                Toggle("Enter manually", isOn: $showManualIssuer)
                    .font(.footnote)
                    .tint(Theme.accent)

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
            Text("Asset").foregroundStyle(Theme.textDim)
        } footer: {
            Text("Pick an asset from your list — the issuer auto-fills. Manage your list in Settings → Assets.")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)
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
                Section {
                    TextField("Name (e.g. QX, CFB)", text: $name)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Issuer identity (60 chars)", text: $issuer)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                    TextField("Note (optional)", text: $note)
                } header: {
                    Text("Asset").foregroundStyle(Theme.textDim)
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.base.ignoresSafeArea())
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
                    .foregroundStyle(Theme.textDim)
                    .listRowBackground(Theme.surface)
            }
            ForEach(store.assets) { a in
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(a.name).font(.headline).foregroundStyle(Theme.text)
                            if a.custom { QBadge(text: "custom") }
                        }
                        Text(a.issuer)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Theme.textDim)
                            .lineLimit(1).truncationMode(.middle)
                        if let n = a.note {
                            Text(n).font(.caption2).foregroundStyle(Theme.textFaint)
                        }
                    }
                    Spacer()
                    if a.custom {
                        Button(role: .destructive) {
                            store.remove(a)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Theme.danger)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(Theme.surface)
                .swipeActions {
                    if a.custom {
                        Button(role: .destructive) {
                            store.remove(a)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.base.ignoresSafeArea())
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
