# MdView

A dead-simple markdown viewer for macOS.

- **Main panel** renders your markdown natively (headings, lists, tables, code, block quotes, task lists), with **tabs** for keeping multiple documents open at once.
- **Left nav** shows your documents folder as a navigable tree, with a **filter field** at the top to find files fast.
- **Copy for agents** — one-click copy of the document in the format LLMs like best.

Built with SwiftUI and **zero third-party dependencies** — no Electron, no bundled JavaScript, no network access required.

<!-- Add a screenshot here once you've built it: ![MdView](docs/screenshot.png) -->

## Why "copy raw markdown" for agents?

When you want to hand a document to an AI agent, **raw markdown is the best format**:

- LLMs are trained heavily on markdown and ingest it natively.
- It's compact and preserves structure (headings, lists, fenced code) with almost no token overhead.
- Rendered **HTML** is worse — verbose, full of tags that waste tokens and add noise.
- **JSON** wrapping adds tokens and gives no benefit *unless* you need to attach metadata.

So MdView's main **Copy** button copies the raw `.md` text. The overflow menu adds:

- **Copy with File-Path Context** — prepends a tiny `<!-- file: path/to/doc.md -->` header so the agent knows what the document is. (This is the one case where a little metadata helps.)

Individual code blocks also have their own copy button on hover.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+ **or** the Swift toolchain from the Command Line Tools (`xcode-select --install`)

## Build & run

### Option A — build a double-clickable app

```sh
./build-app.sh           # produces ./MdView.app
./build-app.sh --open    # build and launch
```

### Option B — open in Xcode

```sh
open Package.swift        # Xcode opens the SwiftPM package
```

Then select the **MdView** scheme and press Run.

### Option C — run from the command line

```sh
swift run MdView
```

## Usage

1. Press **⌘O** (File ▸ Open Folder…) and pick a folder of markdown documents.
2. Browse the tree on the left; type in the filter box to narrow it down.
3. Click a document to open it in a tab; click others to open more tabs. Switch with a click or **⇧⌘]** / **⇧⌘[**, and close the active tab with **⌘W**.
4. Click **Copy** (or **⇧⌘C**) to copy the active document's raw markdown for pasting into an agent.

Use the **▲ (chevron-up)** button in the sidebar header — or **⌘↑** — to re-root the tree at the current folder's parent, and the folder button beside it to pick a different folder.

The last folder you opened is remembered and reopened on launch. **⌘R** reloads the folder from disk.

## Tests

The parsing core lives in a pure-Foundation `MarkdownKit` library so it's fully unit-testable:

```sh
swift test
```

Tests cover the markdown parser (headings, code fences, lists, nested/task lists, tables, block quotes, mixed documents) and the file-tree scan/filter logic.

## Project structure

```
Sources/
  MarkdownKit/        Pure-Foundation core (no UI) — parser + file tree model
    Block.swift         Parsed block model
    MarkdownParser.swift  Block-level markdown parser
    FileNode.swift      Document tree scan + filter
  MdView/             SwiftUI app
    MdViewApp.swift     App entry + menu commands
    ContentView.swift   NavigationSplitView shell
    SidebarView.swift   Filter field + folder tree
    DocumentView.swift  Main panel + copy toolbar
    MarkdownRenderView.swift  Renders blocks as SwiftUI views
    InlineMarkdown.swift  Inline emphasis/links via AttributedString
    AppState.swift      Observable app state
    Clipboard.swift     Pasteboard helper
Tests/
  MarkdownKitTests/   Parser + file-tree tests
```

Inline formatting (bold, italic, links, inline code, strikethrough) is rendered via Apple's built-in `AttributedString(markdown:)`; block-level structure is parsed by `MarkdownKit`.

## License

MIT — see [LICENSE](LICENSE).
