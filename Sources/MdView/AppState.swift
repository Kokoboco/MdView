import SwiftUI
import AppKit
import MarkdownKit

/// Holds the app's observable state: the opened root folder, the document
/// tree, the sidebar filter text and the currently selected document.
@MainActor
final class AppState: ObservableObject {
    @Published var rootURL: URL?
    @Published var tree: [FileNode] = []
    @Published var filter: String = ""
    @Published var selectedURL: URL?
    @Published private(set) var documentText: String = ""
    @Published private(set) var blocks: [Block] = []
    @Published private(set) var loadError: String?

    private let lastFolderKey = "MdView.lastFolderPath"

    init() {
        restoreLastFolder()
    }

    /// The tree after applying the current filter text.
    var filteredTree: [FileNode] {
        FileNode.filter(tree, query: filter)
    }

    // MARK: Folder selection

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a folder of markdown documents"
        if panel.runModal() == .OK, let url = panel.url {
            open(folder: url)
        }
    }

    func open(folder url: URL) {
        rootURL = url
        tree = FileNode.scan(directory: url)
        UserDefaults.standard.set(url.path, forKey: lastFolderKey)

        // Keep the current selection if it still exists, else pick the first file.
        if let selected = selectedURL, FileManager.default.fileExists(atPath: selected.path) {
            load(url: selected)
        } else if let first = firstFile(in: tree) {
            select(first)
        } else {
            clearSelection()
        }
    }

    func reload() {
        guard let root = rootURL else { return }
        open(folder: root)
    }

    /// Whether the current root has a parent directory we can move up into.
    var canGoUp: Bool {
        guard let root = rootURL else { return false }
        let parent = root.deletingLastPathComponent()
        return parent.path != root.path
    }

    /// Re-root the tree at the parent of the current folder.
    func goUp() {
        guard let root = rootURL, canGoUp else { return }
        open(folder: root.deletingLastPathComponent())
    }

    private func restoreLastFolder() {
        guard let path = UserDefaults.standard.string(forKey: lastFolderKey) else { return }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            open(folder: url)
        }
    }

    // MARK: Selection / loading

    func select(_ url: URL) {
        selectedURL = url
        load(url: url)
    }

    private func clearSelection() {
        selectedURL = nil
        documentText = ""
        blocks = []
        loadError = nil
    }

    private func load(url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            documentText = text
            blocks = MarkdownParser.parse(text)
            loadError = nil
        } catch {
            documentText = ""
            blocks = []
            loadError = "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func firstFile(in nodes: [FileNode]) -> URL? {
        for node in nodes {
            if node.isDirectory {
                if let found = firstFile(in: node.children ?? []) { return found }
            } else {
                return node.url
            }
        }
        return nil
    }

    // MARK: Copy actions (tuned for pasting into AI agents)

    /// Raw markdown — the best format to hand an agent: compact and
    /// structure-preserving with no rendering noise.
    func copyRawMarkdown() {
        Clipboard.copy(documentText)
    }

    /// Raw markdown prefixed with a small context header (file path) so an
    /// agent knows what the document is.
    func copyWithContext() {
        guard let url = selectedURL else {
            Clipboard.copy(documentText)
            return
        }
        let path = rootURL.map { url.path.replacingOccurrences(of: $0.path + "/", with: "") } ?? url.lastPathComponent
        let header = "<!-- file: \(path) -->\n\n"
        Clipboard.copy(header + documentText)
    }
}
