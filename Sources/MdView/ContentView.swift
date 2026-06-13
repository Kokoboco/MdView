import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DocumentView()
        }
        .frame(minWidth: 760, minHeight: 480)
    }
}
