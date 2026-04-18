import SwiftUI

struct ResultView: View {
    let result: ExecResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(result.exit_code == 0 ? "OK" : "Exit \(result.exit_code)",
                      systemImage: result.exit_code == 0 ? "checkmark.circle" : "xmark.octagon")
                    .foregroundStyle(result.exit_code == 0 ? .green : .red)
                Spacer()
                Text("\(result.duration_ms) ms").font(.caption).foregroundStyle(.secondary)
                if result.timed_out {
                    Text("timeout").font(.caption).foregroundStyle(.orange)
                }
            }

            if !result.stdout.isEmpty {
                textBlock("stdout", result.stdout)
            }
            if !result.stderr.isEmpty {
                textBlock("stderr", result.stderr)
            }
        }
    }

    @ViewBuilder
    private func textBlock(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = text
                } label: {
                    Image(systemName: "doc.on.doc").font(.caption)
                }
            }
            ScrollView(.horizontal) {
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}
