import SwiftUI

/// 场景短语详情页。
struct SceneDetailView: View {
    let category: String
    let title: String

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SceneDetailViewModel()

    var body: some View {
        List {
            if viewModel.phrases.isEmpty && !viewModel.loading {
                Text("暂无短语，请检查后端或切换目的地。")
                    .foregroundStyle(.secondary)
            }
            ForEach(viewModel.phrases) { phrase in
                PhraseCardView(phrase: phrase)
            }
        }
        .navigationTitle(title)
        .task {
            await viewModel.load(
                language: appState.destination.language,
                category: category
            )
        }
        .overlay {
            if viewModel.loading { ProgressView() }
        }
    }
}

@MainActor
final class SceneDetailViewModel: ObservableObject {
    @Published var phrases: [Phrase] = []
    @Published var loading = false
    @Published var error: String?

    func load(language: String, category: String) async {
        loading = true
        defer { loading = false }
        do {
            let pkg = try await PhraseService.shared.fetchPackage(
                language: language,
                category: category
            )
            phrases = pkg.phrases
        } catch {
            self.error = error.localizedDescription
        }
    }
}
