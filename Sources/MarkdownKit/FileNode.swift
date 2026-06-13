import Foundation

/// A node in the document tree shown in the sidebar. Folders carry `children`;
/// markdown files have `nil` children. Identity is the file URL so selection
/// and expansion state survive re-filtering.
///
/// Lives in MarkdownKit (Foundation-only) so its scanning/filtering logic is
/// unit-testable without the SwiftUI layer.
public struct FileNode: Identifiable, Hashable, Sendable {
    public let url: URL
    public let isDirectory: Bool
    public var children: [FileNode]?

    public var id: URL { url }
    public var name: String { url.lastPathComponent }

    public init(url: URL, isDirectory: Bool, children: [FileNode]? = nil) {
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
    }

    public static let markdownExtensions: Set<String> =
        ["md", "markdown", "mdown", "mkd", "mkdn", "mdx", "text", "txt"]

    public static func isMarkdown(_ url: URL) -> Bool {
        markdownExtensions.contains(url.pathExtension.lowercased())
    }

    /// Recursively scan `directory`, keeping markdown files and any folder that
    /// (transitively) contains one. Hidden entries are skipped.
    public static func scan(directory: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var folders: [FileNode] = []
        var files: [FileNode] = []

        for entry in entries {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                let children = scan(directory: entry)
                if !children.isEmpty {
                    folders.append(FileNode(url: entry, isDirectory: true, children: children))
                }
            } else if isMarkdown(entry) {
                files.append(FileNode(url: entry, isDirectory: false, children: nil))
            }
        }

        return sortedByName(folders) + sortedByName(files)
    }

    private static func sortedByName(_ nodes: [FileNode]) -> [FileNode] {
        nodes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Filter a tree by a case-insensitive substring query.
    ///
    /// - A file is kept when its name matches.
    /// - A folder is kept when its name matches (its whole subtree is then kept)
    ///   or when any descendant is kept.
    /// - An empty/whitespace query returns the tree unchanged.
    public static func filter(_ nodes: [FileNode], query: String) -> [FileNode] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return nodes }
        return nodes.compactMap { $0.filtered(matching: needle) }
    }

    private func filtered(matching needle: String) -> FileNode? {
        let selfMatches = name.lowercased().contains(needle)
        if isDirectory {
            if selfMatches { return self } // keep the whole matching folder
            let keptChildren = (children ?? []).compactMap { $0.filtered(matching: needle) }
            guard !keptChildren.isEmpty else { return nil }
            return FileNode(url: url, isDirectory: true, children: keptChildren)
        } else {
            return selfMatches ? self : nil
        }
    }

    /// All file (non-directory) URLs in the tree, depth-first.
    public func allFiles() -> [URL] {
        if !isDirectory { return [url] }
        return (children ?? []).flatMap { $0.allFiles() }
    }
}
