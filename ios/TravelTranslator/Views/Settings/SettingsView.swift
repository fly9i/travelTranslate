import SwiftUI

/// 设置页 · 按组的抬升卡片，行内用 iOS 风格的 label + 控件。
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showUserLocalePicker = false
    @State private var showDestinationPicker = false

    var body: some View {
        ZStack {
            Theme.BG.base.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("设置")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.FG.primary)
                        .padding(.horizontal, 4)

                    languageGroup
                    translateGroup
                    serviceGroup
                    aboutGroup

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 140)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showUserLocalePicker) {
            UserLocalePickerSheet(selection: $appState.userLocale)
        }
        .sheet(isPresented: $showDestinationPicker) {
            DestinationPickerView(selection: $appState.destination)
        }
    }

    // MARK: - Groups

    private var languageGroup: some View {
        settingsCard(title: "语言") {
            detailRow(
                icon: "globe",
                iconChip: .sky,
                title: "我的母语",
                detail: "\(appState.userLocale.flag) \(appState.userLocale.name)"
            ) {
                showUserLocalePicker = true
            }
            rowDivider
            detailRow(
                icon: "mappin.and.ellipse",
                iconChip: .peach,
                title: "目的地",
                detail: "\(appState.destination.flag) \(appState.destination.name)"
            ) {
                showDestinationPicker = true
            }
        }
    }

    private var translateGroup: some View {
        settingsCard(title: "翻译") {
            toggleRow(
                icon: "sparkles",
                iconChip: .lilac,
                title: "文化润色",
                subtitle: "LLM 地道化 + 文化提醒",
                isOn: $appState.culturalPolish
            )
        }
    }

    private var serviceGroup: some View {
        settingsCard(title: "服务") {
            valueRow(
                icon: "server.rack",
                iconChip: .mint,
                title: "后端地址",
                value: APIConfig.baseURL.absoluteString
            )
        }
    }

    private var aboutGroup: some View {
        settingsCard(title: "关于") {
            valueRow(
                icon: "app.badge",
                iconChip: .peach,
                title: "应用",
                value: "TravelTranslator"
            )
            rowDivider
            valueRow(
                icon: "number",
                iconChip: .vanilla,
                title: "版本",
                value: Self.appVersion
            )
        }
    }

    // MARK: - Helpers

    private func settingsCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: title)
            VStack(spacing: 0) {
                content()
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

    private var rowDivider: some View {
        Divider()
            .background(Theme.FG.primary.opacity(0.05))
            .padding(.leading, 58)
    }

    private func rowIcon(_ name: String, chip: Theme.Chip) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(chip.fg)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(chip.bg)
            )
    }

    private func detailRow(
        icon: String,
        iconChip: Theme.Chip,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                rowIcon(icon, chip: iconChip)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.FG.primary)
                Spacer()
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.FG.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.FG.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(
        icon: String,
        iconChip: Theme.Chip,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            rowIcon(icon, chip: iconChip)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.FG.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.FG.tertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.Accent.base)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func valueRow(
        icon: String,
        iconChip: Theme.Chip,
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 12) {
            rowIcon(icon, chip: iconChip)
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(Theme.FG.primary)
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Theme.FG.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let b = info?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

// MARK: - User locale picker

private struct UserLocalePickerSheet: View {
    @Binding var selection: UserLocale
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    private var filtered: [UserLocale] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return UserLocales.all }
        return UserLocales.all.filter { locale in
            locale.name.localizedCaseInsensitiveContains(trimmed)
                || locale.code.localizedCaseInsensitiveContains(trimmed)
                || locale.language.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        ZStack {
            Theme.BG.base.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button("取消") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.FG.secondary)
                    Spacer()
                    Text("选择母语")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.FG.primary)
                    Spacer()
                    Text("取消")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.clear)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .background(
                    Theme.BG.base.overlay(
                        Rectangle().fill(Theme.FG.primary.opacity(0.06)).frame(height: 0.5),
                        alignment: .bottom
                    )
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Theme.FG.tertiary)
                            TextField("搜索语言 / 地区", text: $query)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.FG.primary.opacity(0.04))
                        )

                        VStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, locale in
                                Button {
                                    selection = locale
                                    dismiss()
                                } label: {
                                    row(locale)
                                }
                                .buttonStyle(.plain)
                                if idx < filtered.count - 1 {
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
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func row(_ locale: UserLocale) -> some View {
        let selected = locale.code == selection.code
        return HStack(spacing: 12) {
            Text(locale.flag).font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text(locale.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.FG.primary)
                Text(locale.voiceLanguage)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.FG.tertiary)
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
