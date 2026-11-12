import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var history: History

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.accent.opacity(0.15)).frame(width: 40, height: 40)
                        Image(systemName: "clock.fill")
                            .foregroundStyle(Theme.accent)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text("History")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if history.entries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(Theme.textDim)
                        Text("No history yet")
                            .foregroundStyle(Theme.text).font(.headline)
                        Text("Commands you run will appear here.")
                            .font(.caption).foregroundStyle(Theme.textDim)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(history.entries) { entry in
                            NavigationLink(value: entry) {
                                HistoryCard(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Color.clear.frame(height: 24)
            }
        }
        .qubicBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HistoryEntry.self) { entry in
            HistoryDetailView(entry: entry)
        }
    }
}

struct HistoryDetailView: View {
    let entry: HistoryEntry

    private var txHashes: [String] {
        let re = try? NSRegularExpression(pattern: "TxHash:\\s*(\\S+)", options: [])
        guard let re else { return [] }
        let ns = entry.stdoutHead as NSString
        let matches = re.matches(in: entry.stdoutHead, range: NSRange(location: 0, length: ns.length))
        return matches.map { ns.substring(with: $0.range(at: 1)) }
    }

    private var explorerLinks: [String] {
        txHashes.map { "https://explorer.qubic.org/network/tx/" + $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: entry.exitCode == 0 ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(entry.exitCode == 0 ? Theme.success : Theme.danger)
                    Text(entry.flag).font(.system(.headline, design: .monospaced))
                    Spacer()
                    Text(entry.date, style: .relative).font(.caption).foregroundStyle(Theme.textDim)
                }

                if !txHashes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TxHashes (\(txHashes.count))").font(.caption.bold()).foregroundStyle(Theme.textDim)
                        ForEach(txHashes, id: \.self) { h in
                            Text(h)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                                .foregroundStyle(Theme.text)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Command").font(.caption.bold()).foregroundStyle(Theme.textDim)
                    Text(entry.args.joined(separator: " "))
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(Theme.text)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Output (first 2 KB)").font(.caption.bold()).foregroundStyle(Theme.textDim)
                    Text(entry.stdoutHead.isEmpty ? "(empty)" : entry.stdoutHead)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(Theme.text)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(16)
        }
        .qubicBackground()
        .navigationTitle(entry.flag)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if !txHashes.isEmpty {
                        Button {
                            UIPasteboard.general.string = explorerLinks.joined(separator: "\n")
                        } label: { Label("Copy explorer links (\(txHashes.count))", systemImage: "link") }
                        ShareLink(item: explorerLinks.joined(separator: "\n"),
                                  preview: SharePreview("\(entry.flag) — explorer links")) {
                            Label("Share explorer links", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button {
                            UIPasteboard.general.string = txHashes.joined(separator: "\n")
                        } label: { Label("Copy TxHashes (raw)", systemImage: "doc.on.doc") }
                        Divider()
                    }
                    Button {
                        UIPasteboard.general.string = entry.stdoutHead
                    } label: { Label("Copy output", systemImage: "doc.text") }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}

struct HistoryCard: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: entry.exitCode == 0 ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(entry.exitCode == 0 ? Theme.success : Theme.danger)
                    .font(.caption)
                Text(entry.flag)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(entry.date, style: .relative)
                    .font(.caption2).foregroundStyle(Theme.textDim)
            }
            Text(entry.args.joined(separator: " "))
                .font(.caption2)
                .foregroundStyle(Theme.textDim)
                .lineLimit(2)
            if !entry.stdoutHead.isEmpty {
                Text(entry.stdoutHead)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(3)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.base.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }
}
