import Foundation

/// A small, dependency-free block-level markdown parser.
///
/// It handles the constructs a documentation viewer needs: ATX headings,
/// paragraphs, fenced code blocks, ordered/unordered (and nested / task)
/// lists, block quotes, thematic breaks and GitHub-style tables. Inline
/// emphasis, links and code spans are left as raw markdown inside each block
/// so the view layer can render them with the platform's inline parser.
public enum MarkdownParser {

    /// Parse a full markdown document into top-level blocks.
    public static func parse(_ source: String) -> [Block] {
        // Normalise line endings and expand tabs to keep indentation maths simple.
        let normalised = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalised.components(separatedBy: "\n")
        var parser = LineParser(lines: lines)
        return parser.parseBlocks(minIndent: 0)
    }
}

// MARK: - Implementation

private struct LineParser {
    let lines: [String]
    var index = 0

    init(lines: [String]) {
        self.lines = lines
    }

    var atEnd: Bool { index >= lines.count }

    func line(at i: Int) -> String? {
        guard i >= 0 && i < lines.count else { return nil }
        return lines[i]
    }

    /// Parse a sequence of blocks. `minIndent` lets nested contexts (lists,
    /// block quotes) treat already-stripped indentation as the new baseline.
    mutating func parseBlocks(minIndent: Int) -> [Block] {
        var blocks: [Block] = []

        while index < lines.count {
            let raw = lines[index]

            // Skip blank lines between blocks.
            if raw.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            if let fence = parseFencedCode() {
                blocks.append(fence)
                continue
            }
            if let heading = parseHeading() {
                blocks.append(heading)
                index += 1
                continue
            }
            if isThematicBreak(raw) {
                blocks.append(Block(.thematicBreak))
                index += 1
                continue
            }
            if let table = parseTable() {
                blocks.append(table)
                continue
            }
            if isBlockQuote(raw) {
                blocks.append(parseBlockQuote())
                continue
            }
            if listMarker(of: raw) != nil {
                blocks.append(parseList(minIndent: minIndent))
                continue
            }

            blocks.append(parseParagraph(minIndent: minIndent))
        }

        return blocks
    }

    // MARK: Headings

    mutating func parseHeading() -> Block? {
        let raw = lines[index]
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }

        var level = 0
        var rest = Substring(trimmed)
        while rest.first == "#" && level < 6 {
            level += 1
            rest = rest.dropFirst()
        }
        // Require a space (or end of line) after the hashes to be a heading.
        guard rest.isEmpty || rest.first == " " else { return nil }

        var text = String(rest).trimmingCharacters(in: .whitespaces)
        // Strip an optional closing run of hashes ("## Title ##").
        while text.hasSuffix("#") {
            text = String(text.dropLast())
        }
        text = text.trimmingCharacters(in: .whitespaces)
        return Block(.heading(level: level, text: text))
    }

    // MARK: Fenced code

    mutating func parseFencedCode() -> Block? {
        let raw = lines[index]
        let indent = leadingSpaces(raw)
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let fenceChar: Character
        if trimmed.hasPrefix("```") {
            fenceChar = "`"
        } else if trimmed.hasPrefix("~~~") {
            fenceChar = "~"
        } else {
            return nil
        }

        let info = trimmed.drop(while: { $0 == fenceChar })
            .trimmingCharacters(in: .whitespaces)
        let language = info.isEmpty ? nil : info.components(separatedBy: " ").first

        index += 1
        var codeLines: [String] = []
        while index < lines.count {
            let l = lines[index]
            let t = l.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix(String(repeating: fenceChar, count: 3)),
               t.allSatisfy({ $0 == fenceChar }) {
                index += 1 // consume the closing fence
                break
            }
            // Drop the opening fence's indentation from each content line.
            codeLines.append(dropLeading(spaces: indent, from: l))
            index += 1
        }

        let code = codeLines.joined(separator: "\n")
        return Block(.codeBlock(language: language, code: code))
    }

    // MARK: Block quotes

    func isBlockQuote(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }

    mutating func parseBlockQuote() -> Block {
        var inner: [String] = []
        while index < lines.count {
            let raw = lines[index]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(">") {
                var content = Substring(trimmed.dropFirst())
                if content.first == " " { content = content.dropFirst() }
                inner.append(String(content))
                index += 1
            } else if trimmed.isEmpty {
                break
            } else {
                // Lazy continuation line.
                inner.append(raw)
                index += 1
            }
        }
        var sub = LineParser(lines: inner)
        let blocks = sub.parseBlocks(minIndent: 0)
        return Block(.blockQuote(blocks: blocks))
    }

    // MARK: Lists

    /// Describes a list-item marker found at the start of a line.
    struct Marker {
        var indent: Int       // leading spaces before the marker
        var ordered: Bool
        var number: Int       // for ordered lists
        var contentColumn: Int // column where the item's text begins
        var checked: Bool?
    }

    func listMarker(of raw: String) -> Marker? {
        let indent = leadingSpaces(raw)
        let afterIndent = raw.dropFirst(indent)
        guard let first = afterIndent.first else { return nil }

        // Unordered: -, *, +
        if first == "-" || first == "*" || first == "+" {
            let next = afterIndent.dropFirst().first
            guard next == " " || next == nil else { return nil }
            let spaces = countLeadingSpaces(afterIndent.dropFirst())
            let contentColumn = indent + 1 + spaces
            return Marker(indent: indent, ordered: false, number: 0,
                          contentColumn: contentColumn,
                          checked: taskState(in: raw, contentColumn: contentColumn))
        }

        // Ordered: 1. or 1)
        var digits = ""
        var rest = afterIndent
        while let c = rest.first, c.isNumber {
            digits.append(c)
            rest = rest.dropFirst()
        }
        if !digits.isEmpty, let delim = rest.first, delim == "." || delim == ")" {
            let afterDelim = rest.dropFirst()
            guard afterDelim.first == " " || afterDelim.first == nil else { return nil }
            let spaces = countLeadingSpaces(afterDelim)
            let contentColumn = indent + digits.count + 1 + spaces
            return Marker(indent: indent, ordered: true, number: Int(digits) ?? 1,
                          contentColumn: contentColumn,
                          checked: taskState(in: raw, contentColumn: contentColumn))
        }
        return nil
    }

    /// Detects `[ ]` / `[x]` immediately after a list marker.
    func taskState(in raw: String, contentColumn: Int) -> Bool? {
        let chars = Array(raw)
        guard contentColumn + 2 < chars.count else { return nil }
        guard chars[contentColumn] == "[",
              chars[contentColumn + 2] == "]",
              contentColumn + 3 < chars.count, chars[contentColumn + 3] == " " else { return nil }
        let mark = chars[contentColumn + 1]
        if mark == " " { return false }
        if mark == "x" || mark == "X" { return true }
        return nil
    }

    mutating func parseList(minIndent: Int) -> Block {
        guard let first = listMarker(of: lines[index]) else {
            return parseParagraph(minIndent: minIndent)
        }
        let baseIndent = first.indent
        let ordered = first.ordered
        let start = first.number

        var items: [ListItem] = []
        var currentText: String? = nil
        var currentChildLines: [String] = []
        var currentChecked: Bool? = nil

        func flush() {
            guard let text = currentText else { return }
            var sub = LineParser(lines: currentChildLines)
            let children = sub.parseBlocks(minIndent: 0)
            items.append(ListItem(text: text, children: children, checked: currentChecked))
            currentText = nil
            currentChildLines = []
            currentChecked = nil
        }

        while index < lines.count {
            let raw = lines[index]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                // A blank line continues the list only if the next line belongs to it.
                if let next = line(at: index + 1), belongsToList(next, baseIndent: baseIndent) {
                    currentChildLines.append("")
                    index += 1
                    continue
                } else {
                    break
                }
            }

            if let marker = listMarker(of: raw), marker.indent == baseIndent {
                // New item at this level.
                flush()
                var content = stripMarkerPrefix(raw, marker: marker)
                if marker.checked != nil {
                    // Remove the "[ ] " / "[x] " prefix from the visible text.
                    content = String(content.dropFirst(4))
                }
                currentText = content
                currentChecked = marker.checked
                index += 1
                continue
            }

            if leadingSpaces(raw) > baseIndent {
                // Continuation / nested content for the current item.
                currentChildLines.append(dropLeading(spaces: first.contentColumn, from: raw))
                index += 1
                continue
            }

            // Anything else ends the list.
            break
        }

        flush()
        return Block(.list(ordered: ordered, start: start, items: items))
    }

    /// Remove an item's leading indent, marker token and following spaces,
    /// returning just the item's own inline text.
    func stripMarkerPrefix(_ raw: String, marker: Marker) -> String {
        var s = Substring(raw)
        while let c = s.first, c == " " || c == "\t" { s = s.dropFirst() }
        if marker.ordered {
            while let c = s.first, c.isNumber { s = s.dropFirst() }
            if let c = s.first, c == "." || c == ")" { s = s.dropFirst() }
        } else {
            s = s.dropFirst() // single -, * or +
        }
        while let c = s.first, c == " " || c == "\t" { s = s.dropFirst() }
        return String(s)
    }

    func belongsToList(_ raw: String, baseIndent: Int) -> Bool {
        if raw.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        if let m = listMarker(of: raw), m.indent == baseIndent { return true }
        return leadingSpaces(raw) > baseIndent
    }

    // MARK: Tables

    mutating func parseTable() -> Block? {
        let headerLine = lines[index]
        guard headerLine.contains("|") else { return nil }
        guard let delimiter = line(at: index + 1), isTableDelimiter(delimiter) else { return nil }

        let headers = splitTableRow(headerLine)
        let alignments = parseAlignments(delimiter)
        guard !headers.isEmpty else { return nil }

        index += 2
        var rows: [[String]] = []
        while index < lines.count {
            let raw = lines[index]
            if raw.trimmingCharacters(in: .whitespaces).isEmpty { break }
            if !raw.contains("|") { break }
            rows.append(splitTableRow(raw))
            index += 1
        }

        return Block(.table(headers: headers, alignments: alignments, rows: rows))
    }

    func isTableDelimiter(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-") else { return false }
        let cells = splitTableRow(raw)
        guard !cells.isEmpty else { return false }
        for cell in cells {
            let c = cell.trimmingCharacters(in: .whitespaces)
            if c.isEmpty { return false }
            // Valid delimiter cell: optional leading/trailing ':' around dashes.
            let body = c.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            if body.isEmpty || !body.allSatisfy({ $0 == "-" }) { return false }
        }
        return true
    }

    func parseAlignments(_ raw: String) -> [ColumnAlignment] {
        splitTableRow(raw).map { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            let left = c.hasPrefix(":")
            let right = c.hasSuffix(":")
            switch (left, right) {
            case (true, true): return .center
            case (false, true): return .trailing
            default: return .leading
            }
        }
    }

    func splitTableRow(_ raw: String) -> [String] {
        var trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }

        var cells: [String] = []
        var current = ""
        var escaping = false
        for ch in trimmed {
            if escaping {
                current.append(ch)
                escaping = false
            } else if ch == "\\" {
                current.append(ch)
                escaping = true
            } else if ch == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(ch)
            }
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    // MARK: Paragraphs

    mutating func parseParagraph(minIndent: Int) -> Block {
        var collected: [String] = []
        while index < lines.count {
            let raw = lines[index]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { break }
            // Stop if the line begins a different block type.
            if collected.count > 0 {
                if trimmed.hasPrefix("#") && parseHeadingPeek(raw) { break }
                if trimmed.hasPrefix(">") { break }
                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { break }
                if isThematicBreak(raw) { break }
                if listMarker(of: raw) != nil { break }
                if trimmed.contains("|"), let next = line(at: index + 1), isTableDelimiter(next) { break }
            }
            collected.append(trimmed)
            index += 1
        }
        let text = collected.joined(separator: "\n")
        return Block(.paragraph(text: text))
    }

    func parseHeadingPeek(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        var level = 0
        var rest = Substring(trimmed)
        while rest.first == "#" && level < 7 {
            level += 1
            rest = rest.dropFirst()
        }
        guard level >= 1 && level <= 6 else { return false }
        return rest.isEmpty || rest.first == " "
    }

    // MARK: Thematic break

    func isThematicBreak(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        for marker in ["-", "*", "_"] {
            let stripped = trimmed.replacingOccurrences(of: " ", with: "")
            if !stripped.isEmpty, stripped.allSatisfy({ String($0) == marker }) {
                return true
            }
        }
        return false
    }
}

// MARK: - Whitespace helpers

private func leadingSpaces(_ s: String) -> Int {
    countLeadingSpaces(Substring(s))
}

private func countLeadingSpaces<S: StringProtocol>(_ s: S) -> Int {
    var count = 0
    for ch in s {
        if ch == " " { count += 1 }
        else if ch == "\t" { count += 4 }
        else { break }
    }
    return count
}

/// Remove up to `spaces` columns of leading whitespace, treating tabs as 4.
private func dropLeading(spaces: Int, from s: String) -> String {
    var remaining = spaces
    var chars = Array(s)
    var i = 0
    while i < chars.count && remaining > 0 {
        if chars[i] == " " { remaining -= 1; i += 1 }
        else if chars[i] == "\t" { remaining -= 4; i += 1 }
        else { break }
    }
    return String(chars[i...])
}
