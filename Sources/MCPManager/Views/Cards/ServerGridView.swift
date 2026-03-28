import SwiftUI

struct ServerGridView: View {

    @Environment(AppViewModel.self) private var viewModel

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.displayedServers) { server in
                    ServerCardView(server: server)
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
