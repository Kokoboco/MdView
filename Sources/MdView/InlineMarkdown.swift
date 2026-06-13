import Foundation
import SwiftUI

/// Renders a span of inline markdown (emphasis, code spans, links,
/// strikethrough) to an `AttributedString` using the platform parser.
enum InlineMarkdown {
    static func attributed(_ source: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible
        if let attributed = try? AttributedString(markdown: source, options: options) {
            return attributed
        }
        return AttributedString(source)
    }
}
