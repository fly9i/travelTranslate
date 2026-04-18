import SwiftUI

/// 场景短语详情页。
struct SceneDetailView: View {
    let category: String
    let title: String

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SceneDetailViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.BG.base.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.phrases.isEmpty && !viewModel.loading {
                        Text("暂无短语，请检查后端或切换目的地。")
                            .font(.footnote)
                            .foregroundStyle(Theme.FG.tertiary)
                            .padding(.vertical, 40)
                    }
                    ForEach(viewModel.phrases) { phrase in
                        PhraseCardView(phrase: phrase)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 140)
            }

            if viewModel.loading {
                ProgressView()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(
                language: appState.destination.language,
                category: category
            )
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
