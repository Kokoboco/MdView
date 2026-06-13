import XCTest
@testable import MarkdownKit

final class MarkdownParserTests: XCTestCase {

    // MARK: Helpers

    private func parse(_ s: String) -> [Block.Kind] {
        MarkdownParser.parse(s).map(\.kind)
    }

    // MARK: Headings

    func testATXHeadings() {
        XCTAssertEqual(parse("# Title"), [.heading(level: 1, text: "Title")])
        XCTAssertEqual(parse("### Deep"), [.heading(level: 3, text: "Deep")])
        XCTAssertEqual(parse("###### Six"), [.heading(level: 6, text: "Six")])
    }

    func testHeadingBeyondSixIsParagraph() {
        XCTAssertEqual(parse("####### Nope"), [.paragraph(text: "####### Nope")])
    }

    func testHeadingRequiresSpace() {
        // "#tag" is not a heading.
        XCTAssertEqual(parse("#tag"), [.paragraph(text: "#tag")])
    }

    func testHeadingStripsClosingHashes() {
        XCTAssertEqual(parse("## Title ##"), [.heading(level: 2, text: "Title")])
    }

    // MARK: Paragraphs

    func testParagraphJoinsSoftLines() {
        XCTAssertEqual(parse("one\ntwo"), [.paragraph(text: "one\ntwo")])
    }

    func testBlankLineSeparatesParagraphs() {
        XCTAssertEqual(
            parse("a\n\nb"),
            [.paragraph(text: "a"), .paragraph(text: "b")]
        )
    }

    func testParagraphStopsAtHeading() {
        XCTAssertEqual(
            parse("text\n# Heading"),
            [.paragraph(text: "text"), .heading(level: 1, text: "Heading")]
        )
    }

    // MARK: Fenced code

    func testFencedCodeBlock() {
        let md = """
        ```swift
        let x = 1
        print(x)
        ```
        """
        XCTAssertEqual(parse(md), [.codeBlock(language: "swift", code: "let x = 1\nprint(x)")])
    }

    func testFencedCodeWithoutLanguage() {
        let md = "```\nplain\n```"
        XCTAssertEqual(parse(md), [.codeBlock(language: nil, code: "plain")])
    }

    func testTildeFence() {
        let md = "~~~\ncode\n~~~"
        XCTAssertEqual(parse(md), [.codeBlock(language: nil, code: "code")])
    }

    func testCodeBlockPreservesMarkdownCharacters() {
        let md = "```\n# not a heading\n- not a list\n```"
        XCTAssertEqual(parse(md), [.codeBlock(language: nil, code: "# not a heading\n- not a list")])
    }

    func testUnterminatedFenceConsumesToEnd() {
        let md = "```\nstill code"
        XCTAssertEqual(parse(md), [.codeBlock(language: nil, code: "still code")])
    }

    // MARK: Thematic breaks

    func testThematicBreaks() {
        XCTAssertEqual(parse("---"), [.thematicBreak])
        XCTAssertEqual(parse("***"), [.thematicBreak])
        XCTAssertEqual(parse("___"), [.thematicBreak])
        XCTAssertEqual(parse("- - -"), [.thematicBreak])
    }

    // MARK: Block quotes

    func testBlockQuote() {
        let result = MarkdownParser.parse("> hello\n> world")
        guard case let .blockQuote(blocks) = result.first?.kind else {
            return XCTFail("expected blockquote")
        }
        XCTAssertEqual(blocks.map(\.kind), [.paragraph(text: "hello\nworld")])
    }

    func testNestedBlockQuoteContainsList() {
        let result = MarkdownParser.parse("> - a\n> - b")
        guard case let .blockQuote(blocks) = result.first?.kind,
              case let .list(ordered, _, items) = blocks.first?.kind else {
            return XCTFail("expected blockquote with list")
        }
        XCTAssertFalse(ordered)
        XCTAssertEqual(items.map(\.text), ["a", "b"])
    }

    // MARK: Lists

    func testUnorderedList() {
        guard case let .list(ordered, _, items) = parse("- a\n- b\n- c").first else {
            return XCTFail("expected list")
        }
        XCTAssertFalse(ordered)
        XCTAssertEqual(items.map(\.text), ["a", "b", "c"])
    }

    func testOrderedListStart() {
        guard case let .list(ordered, start, items) = parse("3. first\n4. second").first else {
            return XCTFail("expected ordered list")
        }
        XCTAssertTrue(ordered)
        XCTAssertEqual(start, 3)
        XCTAssertEqual(items.map(\.text), ["first", "second"])
    }

    func testDifferentUnorderedMarkers() {
        guard case let .list(_, _, items) = parse("* a").first else {
            return XCTFail("expected list")
        }
        XCTAssertEqual(items.map(\.text), ["a"])
    }

    func testTaskList() {
        guard case let .list(_, _, items) = parse("- [ ] todo\n- [x] done").first else {
            return XCTFail("expected task list")
        }
        XCTAssertEqual(items.map(\.checked), [false, true])
        XCTAssertEqual(items.map(\.text), ["todo", "done"])
    }

    func testNestedList() {
        let md = """
        - parent
          - child1
          - child2
        - sibling
        """
        guard case let .list(_, _, items) = parse(md).first else {
            return XCTFail("expected list")
        }
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].text, "parent")
        guard case let .list(_, _, children) = items[0].children.first?.kind else {
            return XCTFail("expected nested list")
        }
        XCTAssertEqual(children.map(\.text), ["child1", "child2"])
        XCTAssertEqual(items[1].text, "sibling")
    }

    // MARK: Tables

    func testTable() {
        let md = """
        | Name | Age |
        | --- | --- |
        | Alice | 30 |
        | Bob | 25 |
        """
        guard case let .table(headers, alignments, rows) = parse(md).first else {
            return XCTFail("expected table")
        }
        XCTAssertEqual(headers, ["Name", "Age"])
        XCTAssertEqual(alignments, [.leading, .leading])
        XCTAssertEqual(rows, [["Alice", "30"], ["Bob", "25"]])
    }

    func testTableAlignments() {
        let md = """
        | L | C | R |
        | :--- | :---: | ---: |
        | 1 | 2 | 3 |
        """
        guard case let .table(_, alignments, _) = parse(md).first else {
            return XCTFail("expected table")
        }
        XCTAssertEqual(alignments, [.leading, .center, .trailing])
    }

    func testPipeRowWithoutDelimiterIsParagraph() {
        XCTAssertEqual(parse("a | b | c"), [.paragraph(text: "a | b | c")])
    }

    // MARK: Mixed / integration

    func testMixedDocument() {
        let md = """
        # Title

        Intro paragraph.

        ## Section

        - one
        - two

        ```
        code
        ```

        > quote
        """
        let kinds = parse(md)
        XCTAssertEqual(kinds.count, 6)
        XCTAssertEqual(kinds[0], .heading(level: 1, text: "Title"))
        XCTAssertEqual(kinds[1], .paragraph(text: "Intro paragraph."))
        XCTAssertEqual(kinds[2], .heading(level: 2, text: "Section"))
        if case .list = kinds[3] {} else { XCTFail("expected list") }
        if case .codeBlock = kinds[4] {} else { XCTFail("expected code block") }
        if case .blockQuote = kinds[5] {} else { XCTFail("expected block quote") }
    }

    func testEmptyInput() {
        XCTAssertTrue(parse("").isEmpty)
        XCTAssertTrue(parse("\n\n   \n").isEmpty)
    }

    func testCRLFNormalisation() {
        XCTAssertEqual(parse("# A\r\n\r\nB"), [.heading(level: 1, text: "A"), .paragraph(text: "B")])
    }
}
