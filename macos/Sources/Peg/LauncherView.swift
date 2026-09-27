import PegCore
import SwiftUI

struct LauncherView: View {
    @ObservedObject var model: LauncherModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            search
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
            list
        }
        .frame(width: 640, height: 420)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .preferredColorScheme(.dark)
        .onAppear {
            focused = true
        }
        .onChange(of: model.presentation) { _, _ in
            focused = true
        }
    }

    private var search: some View {
        HStack(spacing: 12) {
            Image(systemName: model.mode == .apps ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            TextField("", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .foregroundStyle(Theme.textPrimary)
                .focused($focused)
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    private var list: some View {
        let rows = model.rows
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        rowView(row, selected: index == model.selection)
                            .onTapGesture {
                                model.activate(index)
                            }
                    }
                }
                .padding(8)
            }
            .id(model.presentation)
            .overlay {
                if model.count == 0 {
                    Text(emptyMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(24)
                }
            }
            .onChange(of: model.selection) { _, newValue in
                let current = model.rows
                guard current.indices.contains(newValue) else { return }
                proxy.scrollTo(current[newValue].id)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: LauncherRow, selected: Bool) -> some View {
        switch row.content {
        case .app(let item):
            AppRow(item: item, selected: selected)
        case .clip(let entry):
            ClipRow(entry: entry, selected: selected)
        }
    }

    private var emptyMessage: String {
        if !model.query.isEmpty {
            return "一致する項目がありません"
        }
        switch model.mode {
        case .apps:
            return "~/.config/peg/apps.csv にアプリのパスを追加してください"
        case .clipboard:
            return "クリップボード履歴はまだありません"
        }
    }
}

struct AppRow: View {
    let item: AppItem
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 32, height: 32)
            Text(item.entry.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(selected ? Theme.accent.opacity(0.28) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .contentShape(Rectangle())
    }
}

struct ClipRow: View {
    let entry: ClipEntry
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.preview)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text(entry.copiedAt, format: .relative(presentation: .numeric))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(selected ? Theme.accent.opacity(0.28) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .contentShape(Rectangle())
    }
}
