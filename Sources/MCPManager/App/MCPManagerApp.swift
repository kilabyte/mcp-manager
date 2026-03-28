import SwiftUI

@main
struct MCPManagerApp: App {

    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .onAppear {
                    viewModel.loadAll()
                }
        }
        .defaultSize(width: 1100, height: 700)
    }
}
