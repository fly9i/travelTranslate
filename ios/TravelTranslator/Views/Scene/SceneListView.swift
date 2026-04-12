import SwiftUI

/// 场景总览页。
struct SceneListView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Scenes.all) { scene in
                    NavigationLink {
                        SceneDetailView(
                            category: scene.category,
                            title: "\(scene.icon) \(scene.label)常用"
                        )
                    } label: {
                        VStack(spacing: 6) {
                            Text(scene.icon).font(.system(size: 44))
                            Text(scene.label).font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("场景短语本")
    }
}
