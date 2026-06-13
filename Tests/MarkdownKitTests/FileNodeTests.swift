import XCTest
@testable import MarkdownKit

final class FileNodeTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MdViewTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ relativePath: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "content".write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: isMarkdown

    func testIsMarkdownRecognisesExtensions() {
        XCTAssertTrue(FileNode.isMarkdown(URL(fileURLWithPath: "/x/readme.md")))
        XCTAssertTrue(FileNode.isMarkdown(URL(fileURLWithPath: "/x/Notes.MARKDOWN")))
        XCTAssertFalse(FileNode.isMarkdown(URL(fileURLWithPath: "/x/image.png")))
    }

    // MARK: scan

    func testScanFindsMarkdownAndPrunesNonMarkdownFolders() throws {
        try write("readme.md")
        try write("docs/guide.md")
        try write("assets/logo.png") // folder with no markdown -> pruned

        let tree = FileNode.scan(directory: root)
        let names = tree.map(\.name).sorted()
        XCTAssertEqual(names, ["docs", "readme.md"]) // assets pruned, no png file

        let docs = tree.first { $0.name == "docs" }
        XCTAssertEqual(docs?.children?.map(\.name), ["guide.md"])
    }

    func testScanSortsFoldersBeforeFiles() throws {
        try write("zeta.md")
        try write("alpha/a.md")
        let tree = FileNode.scan(directory: root)
        XCTAssertEqual(tree.map(\.name), ["alpha", "zeta.md"])
    }

    // MARK: filter

    private func sampleTree() -> [FileNode] {
        [
            FileNode(url: URL(fileURLWithPath: "/r/guide"), isDirectory: true, children: [
                FileNode(url: URL(fileURLWithPath: "/r/guide/intro.md"), isDirectory: false),
                FileNode(url: URL(fileURLWithPath: "/r/guide/advanced.md"), isDirectory: false),
            ]),
            FileNode(url: URL(fileURLWithPath: "/r/readme.md"), isDirectory: false),
        ]
    }

    func testEmptyFilterReturnsAll() {
        let result = FileNode.filter(sampleTree(), query: "   ")
        XCTAssertEqual(result.flatMap { $0.allFiles() }.count, 3)
    }

    func testFilterMatchesFileName() {
        let result = FileNode.filter(sampleTree(), query: "intro")
        let files = result.flatMap { $0.allFiles() }.map { $0.lastPathComponent }
        XCTAssertEqual(files, ["intro.md"])
    }

    func testFilterKeepsWholeMatchingFolder() {
        let result = FileNode.filter(sampleTree(), query: "guide")
        let files = result.flatMap { $0.allFiles() }.map { $0.lastPathComponent }.sorted()
        XCTAssertEqual(files, ["advanced.md", "intro.md"])
    }

    func testFilterIsCaseInsensitive() {
        let result = FileNode.filter(sampleTree(), query: "README")
        XCTAssertEqual(result.flatMap { $0.allFiles() }.map { $0.lastPathComponent }, ["readme.md"])
    }

    func testFilterNoMatch() {
        XCTAssertTrue(FileNode.filter(sampleTree(), query: "zzz").isEmpty)
    }
}
