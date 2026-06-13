import SwiftUI
import AppKit

/// The main panel: a tab bar over the rendered active document, plus copy
/// actions in the toolbar.
struct DocumentView: View {
    @EnvironmentObject var state: AppState
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            if !state.openDocuments.isEmpty {
                TabBar()
                Divider()
            }
            content
        }
        .frame(minWidth: 400, minHeight: 300)
        .navigationTitle(state.activeDocument?.name ?? "MdView")
        .toolbar { toolbarContent }
    }

    @ViewBuilder
    private var content: some View {
        if let doc = state.activeDocument {
            if let error = doc.loadError {
                message(error, systemImage: "exclamationmark.triangle")
            } else {
                ScrollView {
                    MarkdownRenderView(blocks: doc.blocks)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 22)
                        .frame(maxWidth: 820, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(doc.url) // reset scroll position when switching tabs
            }
        } else {
            message("Select a document to view it", systemImage: "doc.text")
        }
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
            .disabled(state.activeDocument == nil)

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
            .disabled(state.activeDocument == nil)
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

// MARK: - Tab bar

private struct TabBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(state.openDocuments) { doc in
                    TabItem(
                        title: doc.name,
                        isActive: doc.url == state.activeURL,
                        activate: { state.activeURL = doc.url },
                        close: { state.close(doc.url) }
                    )
                    Divider().frame(height: 18)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct TabItem: View {
    let title: String
    let isActive: Bool
    let activate: () -> Void
    let close: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .lineLimit(1)
                .font(.system(size: 12))
                .foregroundStyle(isActive ? Color.primary : Color.secondary)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .opacity(hovering || isActive ? 1 : 0)
            .help("Close tab")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: 200)
        .background(isActive ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.25) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: activate)
        .onHover { hovering = $0 }
    }
}
