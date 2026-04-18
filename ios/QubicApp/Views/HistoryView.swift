import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var history: History

    var body: some View {
        Group {
            if history.entries.isEmpty {
                ContentUnavailableView("No history",
                    systemImage: "clock",
                    description: Text("Commands you run will appear here."))
            } else {
                List(history.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.flag).font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(entry.exitCode == 0 ? "OK" : "exit \(entry.exitCode)")
                                .font(.caption)
                                .foregroundStyle(entry.exitCode == 0 ? .green : .red)
                        }
                        Text(entry.args.joined(separator: " "))
                            .font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text(entry.date, style: .relative)
                            .font(.caption2).foregroundStyle(.tertiary)
                        if !entry.stdoutHead.isEmpty {
                            Text(entry.stdoutHead)
                                .font(.system(.caption2, design: .monospaced))
                                .lineLimit(3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("History")
    }
}
