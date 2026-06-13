import SwiftUI
import AppKit
import MarkdownKit

/// Renders parsed markdown blocks as native SwiftUI views.
struct MarkdownRenderView: View {
    let blocks: [Block]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
                BlockView(block: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
}

private struct BlockView: View {
    let block: Block

    var body: some View {
        switch block.kind {
        case let .heading(level, text):
            HeadingView(level: level, text: text)

        case let .paragraph(text):
            Text(InlineMarkdown.attributed(text))
                .fixedSize(horizontal: false, vertical: true)

        case let .codeBlock(language, code):
            CodeBlockView(language: language, code: code)

        case let .list(ordered, start, items):
            ListView(ordered: ordered, start: start, items: items)

        case let .blockQuote(blocks):
            BlockQuoteView(blocks: blocks)

        case .thematicBreak:
            Divider().padding(.vertical, 4)

        case let .table(headers, alignments, rows):
            TableView(headers: headers, alignments: alignments, rows: rows)
        }
    }
}

// MARK: - Headings

private struct HeadingView: View {
    let level: Int
    let text: String

    var body: some View {
        let content = Text(InlineMarkdown.attributed(text))
            .font(font)
            .fontWeight(.semibold)
            .fixedSize(horizontal: false, vertical: true)

        VStack(alignment: .leading, spacing: 6) {
            content
            if level <= 2 {
                Divider()
            }
        }
        .padding(.top, level <= 2 ? 8 : 2)
    }

    private var font: Font {
        switch level {
        case 1: return .system(size: 28, weight: .bold)
        case 2: return .system(size: 22, weight: .bold)
        case 3: return .system(size: 18, weight: .semibold)
        case 4: return .system(size: 16, weight: .semibold)
        case 5: return .system(size: 14, weight: .semibold)
        default: return .system(size: 13, weight: .semibold)
        }
    }
}

// MARK: - Code blocks

private struct CodeBlockView: View {
    let language: String?
    let code: String
    @State private var copied = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                Clipboard.copy(code)
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .padding(6)
            }
            .buttonStyle(.borderless)
            .help("Copy code")
            .padding(6)
        }
    }
}

// MARK: - Lists

private struct ListView: View {
    let ordered: Bool
    let start: Int
    let items: [ListItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    marker(for: offset, item: item)
                        .frame(minWidth: 18, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(InlineMarkdown.attributed(item.text))
                            .fixedSize(horizontal: false, vertical: true)
                        if !item.children.isEmpty {
                            MarkdownRenderView(blocks: item.children)
                        }
                    }
                }
            }
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private func marker(for offset: Int, item: ListItem) -> some View {
        if let checked = item.checked {
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .foregroundStyle(checked ? Color.accentColor : Color.secondary)
        } else if ordered {
            Text("\(start + offset).")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } else {
            Text("•").foregroundStyle(.secondary)
        }
    }
}

// MARK: - Block quotes

private struct BlockQuoteView: View {
    let blocks: [Block]

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 3)
            MarkdownRenderView(blocks: blocks)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Tables

private struct TableView: View {
    let headers: [String]
    let alignments: [ColumnAlignment]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                        cell(header, column: index, isHeader: true)
                    }
                }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(headers.indices), id: \.self) { index in
                            cell(index < row.count ? row[index] : "", column: index, isHeader: false)
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func cell(_ text: String, column: Int, isHeader: Bool) -> some View {
        Text(InlineMarkdown.attributed(text))
            .fontWeight(isHeader ? .semibold : .regular)
            .frame(maxWidth: .infinity, alignment: alignment(for: column))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isHeader ? Color.secondary.opacity(0.12) : Color.clear)
    }

    private func alignment(for column: Int) -> Alignment {
        guard column < alignments.count else { return .leading }
        switch alignments[column] {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
