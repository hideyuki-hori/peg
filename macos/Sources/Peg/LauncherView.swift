import PegCore
import PegMenu
import PegNotes
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
        .onChange(of: model.focus) { _, target in
            focused = target == .search
        }
        .onChange(of: focused) { _, isFocused in
            if isFocused {
                model.focus = .search
            }
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
        let hints = model.hints
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        rowView(row, selected: index == model.selection)
                            .overlay(alignment: .trailing) {
                                if hints.indices.contains(index) {
                                    HintBadge(label: hints[index], typed: model.hintInput, active: model.hintMode)
                                        .padding(.trailing, 12)
                                }
                            }
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
        case .calculation(let calculation):
            CalculationRow(calculation: calculation, selected: selected)
        case .menu(let item):
            MenuRow(item: item, selected: selected)
        case .note(let note):
            StickyRow(title: note.title, icon: "note.text", selected: selected)
        case .newNote:
            StickyRow(title: "新しい付箋", icon: "plus", selected: selected)
        }
    }

    private var emptyMessage: String {
        if !model.query.isEmpty {
            return ["一致する項目がありません", model.menuMessage].compactMap { $0 }.joined(separator: "\n")
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

struct CalculationRow: View {
    let calculation: Calculation
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "equal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 32, height: 32)
                .background(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            Text(calculation.result)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text(calculation.expression)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text("return でコピー")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .opacity(selected ? 1 : 0)
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

struct HintBadge: View {
    let label: String
    let typed: String
    let active: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(label.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .foregroundStyle(index < typed.count && label.hasPrefix(typed) ? Theme.amber : Theme.textPrimary)
            }
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .padding(.horizontal, 6)
        .frame(height: 20)
        .background(active ? Theme.accent : Theme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .opacity(active ? 1 : 0.55)
    }
}

struct MenuRow: View {
    let item: MenuItem
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "filemenu.and.selection")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 32, height: 32)
            Text(item.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text(item.location)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.trailing, 36)
        .frame(height: 40)
        .background(selected ? Theme.accent.opacity(0.28) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .contentShape(Rectangle())
    }
}

struct StickyRow: View {
    let title: String
    let icon: String
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.amber)
                .frame(width: 32, height: 32)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.trailing, 36)
        .frame(height: 40)
        .background(selected ? Theme.accent.opacity(0.28) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .contentShape(Rectangle())
    }
}
