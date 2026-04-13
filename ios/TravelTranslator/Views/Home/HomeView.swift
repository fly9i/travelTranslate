import SwiftUI

/// 首页：目的地切换 + 场景网格 + 即时翻译。
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @State private var showingDestinationPicker = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 目的地头部：点击弹选择器
                Button {
                    showingDestinationPicker = true
                } label: {
                    HStack {
                        Text("\(appState.destination.flag) \(appState.destination.name)")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("切换").font(.footnote).foregroundStyle(.tint)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // 场景网格
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Scenes.all) { scene in
                        NavigationLink {
                            SceneDetailView(category: scene.category, title: "\(scene.icon) \(scene.label)常用")
                        } label: {
                            sceneCard(scene)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 输入与翻译
                VStack(alignment: .leading, spacing: 8) {
                    TextField("说点什么 / 输入要翻译的内容…", text: $viewModel.input)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task {
                            await viewModel.translate(targetLanguage: appState.destination.language)
                        }
                    } label: {
                        if viewModel.loading {
                            ProgressView()
                        } else {
                            Label("翻译", systemImage: "paperplane.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.input.isEmpty || viewModel.loading)
                }

                if let result = viewModel.result {
                    resultCard(source: viewModel.input, result: result)
                }
                if let error = viewModel.error {
                    Text("错误：\(error)").foregroundStyle(.red)
                }

                NavigationLink("进入实时对话模式 →") {
                    ConversationView()
                }
            }
            .padding()
        }
        .navigationTitle("TravelTranslator")
        .sheet(isPresented: $showingDestinationPicker) {
            DestinationPickerView(selection: $appState.destination)
        }
        .task {
            await appState.bootstrapFromLocation()
        }
    }

    private func sceneCard(_ scene: SceneEntry) -> some View {
        VStack(spacing: 6) {
            Text(scene.icon).font(.system(size: 36))
            Text(scene.label).font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func resultCard(source: String, result: TranslationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(source).foregroundStyle(.secondary)
            Text(result.translatedText).font(.title).bold()
            if let tl = result.transliteration {
                Text(tl).font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                NavigationLink {
                    FullScreenDisplayView(source: source, target: result.translatedText)
                } label: {
                    Label("展示给对方", systemImage: "tv")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var input: String = ""
    @Published var loading: Bool = false
    @Published var result: TranslationResult?
    @Published var error: String?

    func translate(targetLanguage: String) async {
        guard !input.isEmpty else { return }
        loading = true
        error = nil
        do {
            result = try await TranslationService.shared.translate(
                text: input,
                to: targetLanguage,
                context: nil
            )
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
