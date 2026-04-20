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
                            HistoryCard(entry: entry)
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
