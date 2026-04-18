import SwiftUI

// MARK: - Glass Surface

/// 毛玻璃卡片 — 用于浮动 tab bar、镜头界面 chrome。
struct GlassSurface<Content: View>: View {
    var cornerRadius: CGFloat = Theme.Radius.lg
    var dark: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(dark ? 0.1 : 0.7),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(dark ? 0.4 : 0.12), radius: 24, x: 0, y: 12)
    }
}

/// 浮动圆形玻璃按钮（相机顶部 chrome 用）。
struct GlassPillButton: View {
    var systemImage: String
    var size: CGFloat = 40
    var dark: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(dark ? Color.white : Theme.FG.primary)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle().strokeBorder(
                        Color.white.opacity(dark ? 0.15 : 0.7),
                        lineWidth: 0.5
                    )
                )
                .shadow(color: .black.opacity(dark ? 0.35 : 0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Elevated Card

/// 新拟态抬升卡片（内容背景 + 柔阴影）。
struct ElevatedCardModifier: ViewModifier {
    var pad: CGFloat = Theme.Space.l
    var cornerRadius: CGFloat = Theme.Radius.lg

    func body(content: Content) -> some View {
        content
            .padding(pad)
            .background(Theme.BG.elevated)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.FG.primary.opacity(0.04), lineWidth: 0.5)
            )
            .designShadow(Theme.Shadow.soft)
    }
}

extension View {
    func elevatedCard(pad: CGFloat = Theme.Space.l, cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        modifier(ElevatedCardModifier(pad: pad, cornerRadius: cornerRadius))
    }
}

// MARK: - Section Header

struct SectionHeaderView: View {
    let title: String
    var action: (label: String, handler: () -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.FG.tertiary)
            Spacer()
            if let action {
                Button(action.label, action: action.handler)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Accent.deep)
            }
        }
        .padding(.horizontal, Theme.Space.xs)
    }
}

// MARK: - Segmented control (custom, glass-friendly)

struct GlassSegment<T: Hashable>: View {
    let options: [(id: T, label: String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                let active = opt.id == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selection = opt.id
                    }
                } label: {
                    Text(opt.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(active ? Theme.FG.primary : Theme.FG.tertiary)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 14)
                        .background(
                            ZStack {
                                if active {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Theme.BG.elevated)
                                        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.FG.primary.opacity(0.05))
        )
    }
}

// MARK: - Chip / tag badge

struct ChipBadge: View {
    let text: String
    var chip: Theme.Chip = .peach

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(chip.fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous).fill(chip.bg)
            )
    }
}

// MARK: - Number badge (annotation dot)

struct NumberBadge: View {
    let number: Int
    var color: Color = Theme.Accent.base

    var body: some View {
        Text("\(number)")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(.white)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, number >= 10 ? 5 : 0)
            .background(
                Capsule(style: .continuous).fill(color)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white, lineWidth: 1.5)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(color, lineWidth: 0.5)
            )
    }
}

// MARK: - Lang pair pill

struct LangPairPill: View {
    let fromFlag: String
    let toFlag: String
    let toName: String
    var onTap: () -> Void = {}
    var overlay: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(fromFlag).font(.system(size: 18))
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle((overlay ? Color.white : Theme.FG.tertiary).opacity(0.6))
                Text(toFlag).font(.system(size: 18))
                Text(toName)
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(0.7)
            }
            .foregroundStyle(overlay ? Color.white : Theme.FG.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    overlay
                        ? AnyShapeStyle(Color.black.opacity(0.45))
                        : AnyShapeStyle(.ultraThinMaterial)
                )
            )
            .overlay(
                Capsule().strokeBorder(
                    Color.white.opacity(overlay ? 0.18 : 0.6),
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
    }
}
