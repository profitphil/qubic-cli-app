import SwiftUI

struct ResultView: View {
    let result: ExecResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: result.exit_code == 0 ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(result.exit_code == 0 ? Theme.success : Theme.danger)
                Text(result.exit_code == 0 ? "Success" : "Exit \(result.exit_code)")
                    .font(.subheadline).bold()
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(result.duration_ms) ms")
                    .font(.caption).foregroundStyle(Theme.textDim)
                if result.timed_out {
                    QBadge(text: "timeout", color: Theme.warn)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Button {
                    UIPasteboard.general.string = text
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(Theme.accent)
                        .font(.caption)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.base.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            }
        }
    }
}
