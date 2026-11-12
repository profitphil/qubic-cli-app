import SwiftUI

/// Full-screen address book for Settings.
struct AddressesManagerView: View {
    @EnvironmentObject var store: AddressStore
    @State private var showAdd = false

    var body: some View {
        List {
            if store.entries.isEmpty {
                Text("No addresses yet. Tap + to add one.")
                    .foregroundStyle(Theme.textDim)
                    .listRowBackground(Theme.surface)
            }
            ForEach(store.entries) { entry in
                AddressRow(entry: entry)
                    .listRowBackground(Theme.surface)
                    .swipeActions {
                        Button(role: .destructive) {
                            store.remove(entry)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.base.ignoresSafeArea())
        .navigationTitle("Addresses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAddressSheet { label, id, note in
                store.add(label: label, identity: id, note: note)
            }
        }
    }
}

struct AddressRow: View {
    @EnvironmentObject var store: AddressStore
    let entry: QubicAddressEntry
    @State private var editing = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.label).font(.headline).foregroundStyle(Theme.text)
                Text(entry.identity)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(1).truncationMode(.middle)
                if let n = entry.note {
                    Text(n).font(.caption2).foregroundStyle(Theme.textFaint)
                }
            }
            Spacer()
            Button {
                UIPasteboard.general.string = entry.identity
            } label: {
                Image(systemName: "doc.on.doc").foregroundStyle(Theme.textDim)
            }
            .buttonStyle(.plain)
            Button {
                editing = true
            } label: {
                Image(systemName: "pencil").foregroundStyle(Theme.textDim)
            }
            .buttonStyle(.plain)
            Button(role: .destructive) {
                store.remove(entry)
            } label: {
                Image(systemName: "trash").foregroundStyle(Theme.danger)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $editing) {
            EditAddressSheet(entry: entry) { label, note in
                store.update(entry, label: label, note: note)
            }
        }
    }
}

struct AddAddressSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var identity = ""
    @State private var note = ""
    let onSave: (String, String, String?) -> Void

    private var valid: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
            && identity.trimmingCharacters(in: .whitespaces).count == 60
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label (e.g. Main wallet)", text: $label)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                Section {
                    TextField("60-char identity", text: $identity)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } footer: {
                    Text("\(identity.count)/60 characters")
                        .font(.caption).foregroundStyle(identity.count == 60 ? .green : .secondary)
                }
                Section {
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("Add address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(label, identity, note.isEmpty ? nil : note)
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
    }
}

struct EditAddressSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: QubicAddressEntry
    @State private var label: String
    @State private var note: String
    let onSave: (String, String?) -> Void

    init(entry: QubicAddressEntry, onSave: @escaping (String, String?) -> Void) {
        self.entry = entry
        self._label = State(initialValue: entry.label)
        self._note = State(initialValue: entry.note ?? "")
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label", text: $label)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                Section {
                    Text(entry.identity)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                } header: {
                    Text("Identity (read-only)")
                }
                Section {
                    TextField("Note", text: $note)
                }
            }
            .navigationTitle("Edit address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(label, note.isEmpty ? nil : note)
                        dismiss()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// Small picker used inside command forms to pick a saved address for an
/// `address`-type arg. Shown next to the text field.
struct AddressPickerButton: View {
    @EnvironmentObject var store: AddressStore
    @Binding var value: String
    @State private var presenting = false

    var body: some View {
        Button {
            presenting = true
        } label: {
            Image(systemName: "person.crop.circle.badge.plus")
        }
        .buttonStyle(.plain)
        .disabled(store.entries.isEmpty)
        .sheet(isPresented: $presenting) {
            NavigationStack {
                List {
                    if store.entries.isEmpty {
                        Text("No saved addresses. Add some in Settings → Addresses.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.entries) { e in
                        Button {
                            value = e.identity
                            presenting = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.label).foregroundStyle(.primary)
                                Text(e.identity)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                        }
                    }
                }
                .navigationTitle("Saved addresses")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") { presenting = false }
                    }
                }
            }
        }
    }
}
