# Welcome to MdView

A **dead-simple** markdown viewer for macOS. Open a folder of `.md` files with
**⌘O**, browse them on the left, and read them here.

## Features

- Native rendering — *no* Electron, no bundled JavaScript
- A filterable document tree in the sidebar
- One-click **Copy** of raw markdown, tuned for pasting into AI agents

> Raw markdown is the best format to hand an agent: compact, structure-preserving,
> and free of rendering noise.

## Formatting it handles

1. Ordered and unordered lists
   - including nested items
   - and `inline code`
2. Task lists:
   - [x] render a folder tree
   - [x] filter documents
   - [ ] take over the world

### Code blocks

```swift
func greet(_ name: String) -> String {
    "Hello, \(name)!"
}
```

### Tables

| Format   | Good for an agent? | Why                         |
| :------- | :----------------: | --------------------------- |
| Markdown |         ✅         | Compact, native to LLMs     |
| HTML     |         ⚠️         | Verbose, wastes tokens      |
| JSON     |         ➖         | Only if you need metadata   |

---

Happy reading!
