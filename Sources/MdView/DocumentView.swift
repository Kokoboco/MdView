import SwiftUI

/// The main panel: renders the selected document and offers copy actions.
struct DocumentView: View {
    @EnvironmentObject var state: AppState
    @State private var copied = false

    var body: some View {
        Group {
            if let error = state.loadError {
                message(error, systemImage: "exclamationmark.triangle")
            } else if state.selectedURL == nil {
                message("Select a document to view it", systemImage: "doc.text")
            } else {
                ScrollView {
                    MarkdownRenderView(blocks: state.blocks)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 22)
                        .frame(maxWidth: 820, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .navigationTitle(state.selectedURL?.lastPathComponent ?? "MdView")
        .toolbar { toolbarContent }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                state.copyRawMarkdown()
                flashCopied()
            } label: {
                Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .help("Copy raw markdown — the best format to paste into an AI agent")
            .disabled(state.selectedURL == nil)

            Menu {
                Button("Copy Raw Markdown") {
                    state.copyRawMarkdown(); flashCopied()
                }
                Button("Copy with File-Path Context") {
                    state.copyWithContext(); flashCopied()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .help("More copy options")
            .disabled(state.selectedURL == nil)
        }
    }

    private func flashCopied() {
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { copied = false }
        }
    }

    private func message(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
