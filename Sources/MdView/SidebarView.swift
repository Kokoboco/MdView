import SwiftUI
import AppKit
import MarkdownKit

struct SidebarView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            if state.rootURL != nil {
                folderHeader
                Divider()
            }

            FilterField(text: $state.filter)
                .padding(8)

            Divider()

            if state.rootURL == nil {
                emptyState
            } else if state.filteredTree.isEmpty {
                noResults
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        FileTreeView(
                            nodes: state.filteredTree,
                            selection: selectionBinding,
                            forceExpand: !state.filter.trimmingCharacters(in: .whitespaces).isEmpty
                        )
                        .environmentObject(state)
                    }
                    .padding(6)
                }
            }
        }
        .frame(minWidth: 200)
    }

    /// Shows the current root folder with controls to move up to its parent
    /// or pick a different folder.
    private var folderHeader: some View {
        HStack(spacing: 6) {
            Button {
                state.goUp()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(!state.canGoUp)
            .help("Go to parent folder")

            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
            Text(state.rootURL?.lastPathComponent ?? "")
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.head)

            Spacer(minLength: 0)

            Button {
                state.chooseFolder()
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.borderless)
            .help("Open a different folder")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    /// Selecting a node loads its document through `AppState`.
    private var selectionBinding: Binding<URL?> {
        Binding(
            get: { state.selectedURL },
            set: { if let url = $0 { state.select(url) } }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No folder open")
                .foregroundStyle(.secondary)
            Button("Open Folder…") { state.chooseFolder() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noResults: some View {
        Text("No documents match “\(state.filter)”")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
}

// MARK: - Filter field

private struct FilterField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter documents", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Recursive tree

private struct FileTreeView: View {
    let nodes: [FileNode]
    @Binding var selection: URL?
    let forceExpand: Bool

    var body: some View {
        ForEach(nodes) { node in
            NodeRow(node: node, selection: $selection, forceExpand: forceExpand, depth: 0)
        }
    }
}

private struct NodeRow: View {
    let node: FileNode
    @Binding var selection: URL?
    let forceExpand: Bool
    let depth: Int

    @State private var expanded = true

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: bindingExpanded) {
                ForEach(node.children ?? []) { child in
                    NodeRow(node: child, selection: $selection, forceExpand: forceExpand, depth: depth + 1)
                }
            } label: {
                Label(node.name, systemImage: "folder")
                    .lineLimit(1)
            }
            .padding(.leading, CGFloat(depth) * 10)
        } else {
            fileRow
        }
    }

    private var bindingExpanded: Binding<Bool> {
        Binding(
            get: { forceExpand || expanded },
            set: { expanded = $0 }
        )
    }

    private var fileRow: some View {
        let isSelected = selection == node.url
        return HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
            Text(node.name)
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .padding(.leading, CGFloat(depth) * 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { selection = node.url }
    }
}
