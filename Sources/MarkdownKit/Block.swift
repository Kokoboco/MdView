import Foundation

/// Column text alignment for a markdown table column.
public enum ColumnAlignment: Equatable, Sendable {
    case leading
    case center
    case trailing
}

/// A single item in a list. `text` holds the item's own inline markdown; any
/// nested content (sub-lists, multi-paragraph items) lives in `children`.
public struct ListItem: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var text: String
    public var children: [Block]
    /// `nil` when the item is not a task-list item, otherwise its checked state.
    public var checked: Bool?

    public init(text: String, children: [Block] = [], checked: Bool? = nil) {
        self.text = text
        self.children = children
        self.checked = checked
    }

    public static func == (lhs: ListItem, rhs: ListItem) -> Bool {
        lhs.text == rhs.text && lhs.children == rhs.children && lhs.checked == rhs.checked
    }
}

/// A parsed block-level markdown element. Inline strings (e.g. paragraph text,
/// heading text, list-item text) keep their raw markdown so the view layer can
/// render emphasis/links/code via the platform's inline markdown support.
public struct Block: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var kind: Kind

    public init(_ kind: Kind) {
        self.kind = kind
    }

    public indirect enum Kind: Equatable, Sendable {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case codeBlock(language: String?, code: String)
        case list(ordered: Bool, start: Int, items: [ListItem])
        case blockQuote(blocks: [Block])
        case thematicBreak
        case table(headers: [String], alignments: [ColumnAlignment], rows: [[String]])
    }

    public static func == (lhs: Block, rhs: Block) -> Bool {
        lhs.kind == rhs.kind
    }
}
