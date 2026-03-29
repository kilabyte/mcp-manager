import AppKit
import SwiftUI

@main
struct MCPManagerApp: App {

    @State private var viewModel = AppViewModel()

    init() {
        // Ensure the app appears in the Dock with its icon,
        // even when launched from a non-Xcode SPM bundle.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .onAppear {
                    viewModel.loadAll()
                    viewModel.loadKeychain()
                }
        }
        .defaultSize(width: 1100, height: 700)
    }
}
