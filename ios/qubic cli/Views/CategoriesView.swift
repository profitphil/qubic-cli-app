import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var catalog: Catalog
    @State private var search = ""

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Hero
                HStack(alignment: .center, spacing: 12) {
                    Image("QubicLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Qubic CLI")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.text)
                        Text("\(catalog.commands.count) commands · \(catalog.categories.count) categories")
                            .font(.caption)
                            .foregroundStyle(Theme.textDim)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if search.isEmpty {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(catalog.categories.sorted(by: { $0.order < $1.order })) { cat in
                            NavigationLink(value: cat) {
                                CategoryCard(category: cat, count: catalog.commands(in: cat.name).count)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    LazyVStack(spacing: 10) {
                        let results = catalog.search(search)
                        if results.isEmpty {
                            Text("No matches for “\(search)”")
                                .foregroundStyle(Theme.textDim)
                                .padding(.top, 40)
                        }
                        ForEach(results) { cmd in
                            NavigationLink(value: cmd) {
                                CommandCard(command: cmd)
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
        .searchable(text: $search, prompt: "Search commands")
        .navigationDestination(for: CommandCategory.self) { CommandListView(category: $0) }
        .navigationDestination(for: Command.self) { CommandDetailView(command: $0) }
    }
}

struct CategoryCard: View {
    let category: CommandCategory
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: category.icon)
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 18, weight: .semibold))
            }
            Spacer(minLength: 4)
            Text(category.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Text("\(count) \(count == 1 ? "command" : "commands")")
                .font(.caption)
                .foregroundStyle(Theme.textDim)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }
}

struct CommandCard: View {
    @EnvironmentObject var history: History
    let command: Command

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.system(size: 14, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(command.flag)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    if history.isFavorite(command.flag) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Theme.accent)
                            .font(.caption2)
                    }
                    Spacer()
                    if command.readOnly { QBadge(text: "read", color: Theme.accent) }
                    if command.needsSeed { QBadge(text: "signs", color: Theme.warn) }
                }
                Text(command.description)
                    .font(.caption)
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private var tint: Color {
        if command.readOnly { return Theme.accent }
        if command.needsSeed { return Theme.warn }
        return Color.purple.opacity(0.85)
    }

    private var icon: String {
        if command.readOnly { return "eye" }
        if command.needsSeed { return "key.fill" }
        return "bolt"
    }
}

// Back-compat alias so other views (FavoritesView, CommandListView) compile.
struct CommandRow: View {
    let command: Command
    var body: some View { CommandCard(command: command) }
}
