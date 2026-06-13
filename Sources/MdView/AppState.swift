import SwiftUI
import AppKit
import MarkdownKit

/// A single open document (one tab).
struct OpenDocument: Identifiable, Equatable {
    let url: URL
    var text: String
    var blocks: [Block]
    var loadError: String?

    var id: URL { url }
    var name: String { url.lastPathComponent }

    static func == (lhs: OpenDocument, rhs: OpenDocument) -> Bool {
        lhs.url == rhs.url && lhs.text == rhs.text && lhs.loadError == rhs.loadError
    }
}

/// Holds the app's observable state: the opened root folder, the document
/// tree, the sidebar filter text and the set of open document tabs.
@MainActor
final class AppState: ObservableObject {
    @Published var rootURL: URL?
    @Published var tree: [FileNode] = []
    @Published var filter: String = ""

    /// Open document tabs, in display order.
    @Published private(set) var openDocuments: [OpenDocument] = []
    /// The URL of the active (frontmost) tab.
    @Published var activeURL: URL?

    private let lastFolderKey = "MdView.lastFolderPath"

    init() {
        restoreLastFolder()
    }

    /// The tree after applying the current filter text.
    var filteredTree: [FileNode] {
        FileNode.filter(tree, query: filter)
    }

    /// The document shown in the main panel.
    var activeDocument: OpenDocument? {
        guard let activeURL else { return nil }
        return openDocuments.first { $0.url == activeURL }
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

        // Keep tabs whose files still exist (e.g. when moving up a level).
        openDocuments.removeAll { !FileManager.default.fileExists(atPath: $0.url.path) }
        if let active = activeURL, !openDocuments.contains(where: { $0.url == active }) {
            activeURL = openDocuments.first?.url
        }
        // Open the first document for a fresh folder with nothing already open.
        if openDocuments.isEmpty, let first = firstFile(in: tree) {
            select(first)
        }
    }

    /// Re-scan the folder and reload the contents of all open tabs.
    func reload() {
        guard let root = rootURL else { return }
        tree = FileNode.scan(directory: root)
        openDocuments = openDocuments
            .filter { FileManager.default.fileExists(atPath: $0.url.path) }
            .map { loadDocument($0.url) }
        if let active = activeURL, !openDocuments.contains(where: { $0.url == active }) {
            activeURL = openDocuments.first?.url
        }
    }

    /// Whether the current root has a parent directory we can move up into.
    var canGoUp: Bool {
        guard let root = rootURL else { return false }
        return root.deletingLastPathComponent().path != root.path
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

    // MARK: Tabs

    /// Open `url` in a tab (or switch to it if already open) and make it active.
    func select(_ url: URL) {
        if !openDocuments.contains(where: { $0.url == url }) {
            openDocuments.append(loadDocument(url))
        }
        activeURL = url
    }

    /// Close the tab for `url`, activating a neighbour if it was frontmost.
    func close(_ url: URL) {
        guard let index = openDocuments.firstIndex(where: { $0.url == url }) else { return }
        openDocuments.remove(at: index)
        if activeURL == url {
            if openDocuments.isEmpty {
                activeURL = nil
            } else {
                activeURL = openDocuments[min(index, openDocuments.count - 1)].url
            }
        }
    }

    func closeActive() {
        if let activeURL { close(activeURL) }
    }

    func selectNextTab(_ offset: Int) {
        guard !openDocuments.isEmpty else { return }
        let current = activeURL.flatMap { url in openDocuments.firstIndex { $0.url == url } } ?? 0
        let next = (current + offset + openDocuments.count) % openDocuments.count
        activeURL = openDocuments[next].url
    }

    private func loadDocument(_ url: URL) -> OpenDocument {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            return OpenDocument(url: url, text: text, blocks: MarkdownParser.parse(text), loadError: nil)
        } catch {
            return OpenDocument(
                url: url, text: "", blocks: [],
                loadError: "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
            )
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
        Clipboard.copy(activeDocument?.text ?? "")
    }

    /// Raw markdown prefixed with a small context header (file path) so an
    /// agent knows what the document is.
    func copyWithContext() {
        guard let doc = activeDocument else { return }
        let path = rootURL.map { doc.url.path.replacingOccurrences(of: $0.path + "/", with: "") }
            ?? doc.url.lastPathComponent
        let header = "<!-- file: \(path) -->\n\n"
        Clipboard.copy(header + doc.text)
    }
}
