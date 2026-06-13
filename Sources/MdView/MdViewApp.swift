import SwiftUI

@main
struct MdViewApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Folder…") {
                    state.chooseFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Go to Parent Folder") {
                    state.goUp()
                }
                .keyboardShortcut(.upArrow, modifiers: [.command])
                .disabled(!state.canGoUp)

                Button("Reload Folder") {
                    state.reload()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(state.rootURL == nil)
            }

            CommandGroup(after: .pasteboard) {
                Button("Copy Document Markdown") {
                    state.copyRawMarkdown()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(state.activeDocument == nil)
            }

            CommandGroup(after: .windowList) {
                Button("Close Tab") {
                    state.closeActive()
                }
                .keyboardShortcut("w", modifiers: [.command])
                .disabled(state.activeDocument == nil)

                Button("Next Tab") {
                    state.selectNextTab(1)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(state.openDocuments.count < 2)

                Button("Previous Tab") {
                    state.selectNextTab(-1)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(state.openDocuments.count < 2)
            }
        }
    }
}
