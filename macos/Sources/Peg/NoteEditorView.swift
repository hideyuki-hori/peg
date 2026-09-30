import AppKit
import PegCore
import SwiftUI

struct NoteEditorView: View {
    @ObservedObject var model: NoteEditorModel
    @FocusState private var isNaming: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 240)
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 1)
                editor
            }
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
            statusBar
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .onChange(of: model.draftName != nil) { _, naming in
            isNaming = naming
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(Theme.accent)
                Text(model.rootName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Button(action: model.beginNaming) {
                    Image(systemName: "plus")
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("新しいメモ（⌘N）")
                .accessibilityLabel("新しいメモ")
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            if model.draftName != nil {
                namingField
            }
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(model.rows) { row in
                        NoteRowView(
                            row: row,
                            isSelected: row.path == model.selected,
                            isDirty: model.dirty.contains(row.path)
                        ) {
                            model.select(row)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
        }
        .background(Theme.surface)
    }

    private var namingField: some View {
        TextField("名前", text: Binding(
            get: { model.draftName ?? "" },
            set: { model.draftName = $0 }
        ))
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Theme.raised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .focused($isNaming)
        .onSubmit(model.commitNaming)
        .onExitCommand(perform: model.cancelNaming)
    }

    @ViewBuilder
    private var editor: some View {
        if model.selected != nil, model.isEditable {
            NoteTextView(text: model.loadedText, revision: model.revision, onChange: model.edit)
        } else {
            Text(placeholder)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var placeholder: String {
        if !model.isReady {
            return model.status
        }
        if model.selected != nil {
            return "テキストとして開けないファイルです"
        }
        return "左の一覧からファイルを選ぶか、⌘N で新しいメモを作ります"
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if let selected = model.selected {
                Text(selected)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if model.dirty.contains(selected) {
                    Text("未保存")
                        .foregroundStyle(Theme.amber)
                }
            }
            Spacer()
            if model.isSyncing {
                ProgressView()
                    .controlSize(.small)
                Text("同期中")
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text(model.status)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .frame(height: 26)
        .background(Theme.surface)
    }
}

private struct NoteRowView: View {
    let row: NoteRow
    let isSelected: Bool
    let isDirty: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 14)
                Text(row.name)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if isDirty {
                    Circle()
                        .fill(Theme.amber)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("未保存")
                }
            }
            .padding(.leading, 8 + CGFloat(row.depth) * 14)
            .padding(.trailing, 8)
            .frame(height: 26)
            .background(isSelected ? Theme.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        if row.isDirectory {
            return row.isExpanded ? "chevron.down" : "chevron.right"
        }
        return "doc.text"
    }
}

struct NoteTextView: NSViewRepresentable {
    let text: String
    let revision: Int
    let onChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.font = NSFont(name: "JetBrains Mono", size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = NSColor(Theme.textPrimary)
        textView.insertionPointColor = NSColor(Theme.accent)
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 20, height: 18)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        textView.defaultParagraphStyle = style
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onChange = onChange
        guard let textView = coordinator.textView, coordinator.revision != revision else { return }
        coordinator.revision = revision
        textView.string = text
        textView.undoManager?.removeAllActions()
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.scrollToBeginningOfDocument(nil)
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var textView: NSTextView?
        var revision = -1
        var onChange: (String) -> Void

        init(onChange: @escaping (String) -> Void) {
            self.onChange = onChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            onChange(textView.string)
        }
    }
}
