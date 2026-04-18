import SwiftUI

/// 场景总览页：2 列卡片，每张带大 emoji + 柔色圆背景 + 计数。
struct SceneListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query: String = ""

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var filtered: [SceneEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return Scenes.all }
        return Scenes.all.filter { $0.label.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("场景短语")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.FG.primary)
                    Text("\(appState.destination.flag) \(appState.destination.name) · 常用短语")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.FG.tertiary)
                }
                .padding(.horizontal, 4)

                searchField

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, scene in
                        NavigationLink {
                            SceneDetailView(
                                category: scene.category,
                                title: "\(scene.icon) \(scene.label)"
                            )
                        } label: {
                            sceneCard(scene: scene, index: idx)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 140) // 给浮动 TabBar 留位置
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Theme.BG.base.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.FG.tertiary)
            TextField("搜索“过敏”“退税”…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.FG.primary.opacity(0.04))
        )
    }

    private func sceneCard(scene: SceneEntry, index: Int) -> some View {
        let chip = chipForIndex(index)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.BG.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .strokeBorder(Theme.FG.primary.opacity(0.04), lineWidth: 0.5)
                )
                .designShadow(Theme.Shadow.soft)

            Circle()
                .fill(chip.bg)
                .frame(width: 70, height: 70)
                .opacity(0.8)
                .offset(x: 100, y: -10)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(scene.icon)
                    .font(.system(size: 36))
                Spacer(minLength: 14)
                Text(scene.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.FG.primary)
                Text("常用")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.FG.tertiary)
            }
            .padding(18)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private func chipForIndex(_ i: Int) -> Theme.Chip {
        let all: [Theme.Chip] = [.peach, .sky, .lilac, .vanilla, .mint, .sage]
        return all[i % all.count]
    }
}
