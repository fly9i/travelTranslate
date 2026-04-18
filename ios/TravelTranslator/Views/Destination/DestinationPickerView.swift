import SwiftUI

/// 目的地选择器：搜索 + "最近" / "全部目的地" 分组卡片。
struct DestinationPickerView: View {
    @Binding var selection: Destination
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @ObservedObject private var recents = RecentDestinationsStore.shared

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filtered: [Destination] {
        if trimmedQuery.isEmpty { return Destinations.all }
        return Destinations.all.filter { dest in
            dest.name.localizedCaseInsensitiveContains(trimmedQuery)
                || dest.localName.localizedCaseInsensitiveContains(trimmedQuery)
                || dest.code.localizedCaseInsensitiveContains(trimmedQuery)
                || dest.language.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var recentDestinations: [Destination] {
        guard trimmedQuery.isEmpty else { return [] }
        return recents.codes.compactMap { Destinations.byCountryCode($0) }
    }

    var body: some View {
        ZStack {
            Theme.BG.base.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        searchField

                        if !recentDestinations.isEmpty {
                            section(title: "最近", items: recentDestinations)
                        }

                        section(
                            title: trimmedQuery.isEmpty ? "全部目的地" : "搜索结果",
                            items: filtered
                        )

                        if filtered.isEmpty {
                            Text("没有匹配的目的地")
                                .font(.footnote)
                                .foregroundStyle(Theme.FG.tertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button("取消") { dismiss() }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.FG.secondary)
            Spacer()
            Text("选择目的地")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.FG.primary)
            Spacer()
            // 占位，保持标题居中
            Text("取消")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.clear)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(
            Theme.BG.base
                .overlay(
                    Rectangle()
                        .fill(Theme.FG.primary.opacity(0.06))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
        )
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Theme.FG.tertiary)
            TextField("搜索国家 / 语言", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.FG.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.FG.primary.opacity(0.04))
        )
    }

    private func section(title: String, items: [Destination]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: title)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, dest in
                    Button {
                        selection = dest
                        recents.push(dest.code)
                        dismiss()
                    } label: {
                        row(dest)
                    }
                    .buttonStyle(.plain)

                    if idx < items.count - 1 {
                        Divider()
                            .background(Theme.FG.primary.opacity(0.05))
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Theme.BG.elevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.FG.primary.opacity(0.04), lineWidth: 0.5)
            )
            .designShadow(Theme.Shadow.soft)
        }
    }

    private func row(_ dest: Destination) -> some View {
        let selected = dest.code == selection.code
        return HStack(spacing: 12) {
            Text(dest.flag).font(.system(size: 30))
            VStack(alignment: .leading, spacing: 2) {
                Text(dest.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.FG.primary)
                HStack(spacing: 6) {
                    Text(dest.localName)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.FG.tertiary)
                        .lineLimit(1)
                    Text(dest.language.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.FG.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Theme.FG.primary.opacity(0.1), lineWidth: 0.5)
                        )
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.Accent.base))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

/// "最近目的地"存储 — 最多保留 5 个，最新在前。
@MainActor
final class RecentDestinationsStore: ObservableObject {
    static let shared = RecentDestinationsStore()

    @Published private(set) var codes: [String] = []

    private let key = "recent.destinations.v1"
    private let maxCount = 5

    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: key) {
            codes = saved
        }
    }

    func push(_ code: String) {
        var next = codes.filter { $0 != code }
        next.insert(code, at: 0)
        if next.count > maxCount {
            next = Array(next.prefix(maxCount))
        }
        codes = next
        UserDefaults.standard.set(codes, forKey: key)
    }
}
