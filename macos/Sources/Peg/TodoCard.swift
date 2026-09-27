import PegCore
import SwiftUI

struct TodoCard: View {
    @ObservedObject var model: ControlPanelModel
    @ObservedObject var launcher: LauncherModel
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "ToDo") {
                Image(systemName: "checklist")
                    .font(.system(size: 13, weight: .medium))
            } trailing: {
                if model.isTodoReady {
                    Text("残り \(model.todos.filter { !$0.isDone }.count) 件")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            if model.isTodoReady {
                field
                if let message = model.todoMessage {
                    MessageText(text: message)
                }
                list
            } else {
                Text("~/.config/peg/config.json の vaultPath に、保管庫のパスを設定してください")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .onChange(of: focused) { _, isFocused in
            if isFocused {
                launcher.focus = .todo
            }
        }
        .onChange(of: launcher.focus) { _, target in
            focused = target == .todo
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 14)
            TextField("", text: $draft, prompt: Text("タスクを追加").foregroundStyle(Theme.textDim))
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .focused($focused)
                .onSubmit(submit)
            KeyHint(text: "cmd")
            KeyHint(text: "N")
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(Theme.raised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .stroke(focused ? Theme.accent.opacity(0.6) : Color.clear, lineWidth: 1)
        )
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(model.todos) { item in
                    TodoRow(
                        item: item,
                        isOverdue: item.isOverdue(today: model.todoToday),
                        toggle: { model.toggle(item) },
                        remove: { model.remove(item) }
                    )
                }
            }
        }
        .overlay {
            if model.todos.isEmpty {
                Text("タスクはありません")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func submit() {
        if model.addTodo(draft) {
            draft = ""
        }
        focused = true
    }
}

struct TodoRow: View {
    let item: TodoItem
    let isOverdue: Bool
    let toggle: () -> Void
    let remove: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggle) {
                checkbox
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "未完了に戻す" : "完了にする")
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(item.isDone ? Theme.textDim : Theme.textPrimary)
                .strikethrough(item.isDone, color: Theme.textDim)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let due = item.dueText {
                Text(due)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(color(forDue: item))
            }
            if isHovering {
                Button(action: remove) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("削除")
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 10)
        .frame(height: 36)
        .background(isHovering ? Theme.raised : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var checkbox: some View {
        if item.isDone {
            RoundedRectangle(cornerRadius: 5)
                .fill(Theme.accent)
                .frame(width: 18, height: 18)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                )
        } else {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Theme.textDim, lineWidth: 1.5)
                .frame(width: 18, height: 18)
        }
    }

    private func color(forDue item: TodoItem) -> Color {
        if item.isDone {
            return Theme.textDim
        }
        return isOverdue ? Theme.coral : Theme.textSecondary
    }
}

struct KeyHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 5)
            .frame(height: 18)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}
