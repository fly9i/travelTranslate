import SwiftUI

/// 目的地选择器：搜索 + 列表。
struct DestinationPickerView: View {
    @Binding var selection: Destination
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    private var filtered: [Destination] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return Destinations.all }
        return Destinations.all.filter { dest in
            dest.name.localizedCaseInsensitiveContains(trimmed)
                || dest.localName.localizedCaseInsensitiveContains(trimmed)
                || dest.code.localizedCaseInsensitiveContains(trimmed)
                || dest.language.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { dest in
                Button {
                    selection = dest
                    dismiss()
                } label: {
                    row(dest)
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索国家 / 语言")
            .navigationTitle("选择目的地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func row(_ dest: Destination) -> some View {
        HStack(spacing: 12) {
            Text(dest.flag).font(.system(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text(dest.name).font(.body)
                Text("\(dest.localName) · \(dest.language.uppercased())")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if dest.code == selection.code {
                Image(systemName: "checkmark").foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }
}
