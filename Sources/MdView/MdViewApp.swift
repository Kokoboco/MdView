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
                .disabled(state.selectedURL == nil)
            }
        }
    }
}
