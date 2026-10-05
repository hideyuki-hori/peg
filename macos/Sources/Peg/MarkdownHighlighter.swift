import AppKit
import PegNotes

@MainActor
enum MarkdownHighlighter {
    static let bodySize: CGFloat = 15
    private static let headingSizes: [CGFloat] = [26, 21, 18, 16, 15, 15]

    static var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: bodySize),
            .foregroundColor: NSColor(Theme.textPrimary),
            .paragraphStyle: paragraphStyle(spacingBefore: 0)
        ]
    }

    static func apply(to storage: NSTextStorage) {
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: full)
        for span in MarkdownStyler.spans(in: storage.string) {
            let range = NSRange(location: span.location, length: span.length)
            guard NSMaxRange(range) <= storage.length else { continue }
            storage.addAttributes(attributes(for: span.kind), range: range)
            if span.kind == .bold {
                storage.applyFontTraits(.boldFontMask, range: range)
            }
        }
        storage.endEditing()
    }

    private static func attributes(for kind: StyleSpan.Kind) -> [NSAttributedString.Key: Any] {
        switch kind {
        case .heading(let level):
            let size = headingSizes[min(max(level, 1), headingSizes.count) - 1]
            return [
                .font: NSFont.systemFont(ofSize: size, weight: .bold),
                .paragraphStyle: paragraphStyle(spacingBefore: 6)
            ]
        case .marker:
            return [.foregroundColor: NSColor(Theme.textDim)]
        case .bold:
            return [:]
        case .italic:
            return [.obliqueness: 0.2]
        case .code:
            return [
                .font: monospaced(size: bodySize - 1.5),
                .foregroundColor: NSColor(Theme.amber),
                .backgroundColor: NSColor(Theme.raised)
            ]
        case .codeBlock:
            return [.font: monospaced(size: bodySize - 1.5)]
        case .quote:
            return [.foregroundColor: NSColor(Theme.textSecondary)]
        case .listMarker:
            return [.foregroundColor: NSColor(Theme.accent)]
        case .checkbox(let checked):
            return [
                .font: monospaced(size: bodySize - 1.5),
                .foregroundColor: NSColor(checked ? Theme.green : Theme.accent)
            ]
        case .done:
            return [
                .foregroundColor: NSColor(Theme.textDim),
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ]
        }
    }

    private static func monospaced(size: CGFloat) -> NSFont {
        NSFont(name: "JetBrains Mono", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    private static func paragraphStyle(spacingBefore: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        style.paragraphSpacingBefore = spacingBefore
        return style
    }
}
