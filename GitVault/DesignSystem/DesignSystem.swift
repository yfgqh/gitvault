//
//  DesignSystem.swift
//  GitVault
//
//  全应用唯一的设计规范来源（Single Source of Truth）。
//  规则：任何视图都不允许硬编码颜色 / 圆角 / 间距 / 阴影 / 字体，一律走 DS。
//

import SwiftUI

// MARK: - 动态色构造器

/// 深/浅色自动切换的颜色。深色为 App 默认外观。
private func dynamicColor(dark: UInt32, light: UInt32) -> Color {
    Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
    })
}

/// 描边色：深色用白、浅色用黑，alpha 由调用方乘
private func dynamicHairline() -> Color {
    Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
    })
}

/// 带透明度的动态色（玻璃填充用）
private func dynamicColor(darkAlpha: UInt32, lightAlpha: UInt32) -> Color {
    Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: darkAlpha, alpha: 0.72)
            : UIColor(hex: lightAlpha, alpha: 0.88)
    })
}

// MARK: - Design System

enum DS {

    // MARK: 颜色

    /// 页面主背景：深色 #0B0E14（墨黑） / 浅色 #FFFFFF（纯白）
    static let bgPrimary = dynamicColor(dark: 0x0B0E14, light: 0xFFFFFF)

    /// 次级背景：卡片下方、分组底色
    static let bgSecondary = dynamicColor(dark: 0x151A23, light: 0xF5F6FA)

    /// 三级背景：输入框、内嵌小块
    static let bgTertiary = dynamicColor(dark: 0x1C2231, light: 0xECEEF4)

    /// 主文本
    static let textPrimary = dynamicColor(dark: 0xFFFFFF, light: 0x0B0E14)

    /// 次要文本（副标题、说明）
    static let textSecondary = dynamicColor(dark: 0x9AA4B2, light: 0x636B7A)

    /// 三级文本（时间、占位符）
    static let textTertiary = dynamicColor(dark: 0x8A94A6, light: 0x7A8291)

    /// 分割线
    static let separator = dynamicColor(dark: 0x242B39, light: 0xE6E8EF)

    // MARK: 强调色

    static let accent = Color(hex: 0x6E7BFF)
    /// 承载白字时用这个：对白色 4.97:1（accent 只有 3.51:1，不达 AA）
    static let accentSolid = Color(hex: 0x5560E8)
    static let accentAlt = Color(hex: 0xA66CFF)

    /// 主渐变：#6E7BFF → #A66CFF（左上到右下）
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0x6E7BFF), Color(hex: 0xA66CFF)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 横向主渐变（进度条、分隔装饰）
    static let accentGradientHorizontal = LinearGradient(
        colors: [Color(hex: 0x6E7BFF), Color(hex: 0xA66CFF)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// 玻璃材质（仅在少量非滚动场景使用）
    static let cardGlass: Material = .ultraThinMaterial

    /// 玻璃填充：半透明底色，视觉接近 material，但零离屏渲染开销
    static let glassFill = dynamicColor(darkAlpha: 0x1A2130, lightAlpha: 0xEFF1F7)

    /// 品牌 Logo 用的深色点阵底
    static let logoBase = Color(hex: 0x0B0E14)

    // MARK: 语义色

    static let danger = Color(hex: 0xFF5D5D)
    static let success = Color(hex: 0x3DDC97)
    static let warning = Color(hex: 0xFFB020)

    // MARK: 圆角

    enum Radius {
        static let card: CGFloat = 22
        static let cardLarge: CGFloat = 24
        static let chip: CGFloat = 12
        static let button: CGFloat = 16
        static let sheet: CGFloat = 28
        static let cover: CGFloat = 18
    }

    // MARK: 间距（8pt 网格）

    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
        /// 页面左右安全内边距
        static let screen: CGFloat = 20
        /// 为悬浮 Tab Bar 预留的底部空间
        static let tabBarInset: CGFloat = 108
    }

    // MARK: 字体层级（全部基于系统文本样式，天然支持 Dynamic Type）

    enum Typo {
        // 规则：正文字号下限 10pt；新增层级加在这里，不要在视图里直接写 .system(size:)
        /// 34pt Bold — 页面大标题
        static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
        /// 22pt Semibold — 区块标题
        static let title = Font.system(.title2, design: .default).weight(.semibold)
        /// 20pt Semibold — 卡片主标题
        static let cardTitle = Font.system(.title3, design: .default).weight(.semibold)
        /// 17pt Semibold — 列表主文本
        static let headline = Font.system(.headline, design: .default).weight(.semibold)
        /// 16pt Regular — 正文
        static let body = Font.system(.body, design: .default).weight(.regular)
        /// 15pt Regular — 次要正文
        static let bodySmall = Font.system(.subheadline, design: .default).weight(.regular)
        /// 13pt Medium — 说明文字
        static let caption = Font.system(.caption, design: .default).weight(.medium)
        /// 13pt Regular
        static let captionRegular = Font.system(.caption, design: .default).weight(.regular)
        /// 11pt Semibold — 角标、极小标签
        static let micro = Font.system(.caption2, design: .default).weight(.semibold)
        /// 等宽数字（Star 数、增量）
        static let mono = Font.system(.footnote, design: .monospaced).weight(.medium)
    }

    // MARK: 阴影

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        /// 柔和投影（卡片默认）
        static let soft = Shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
        /// 轻投影（Chip、小卡片）
        static let light = Shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        /// 强调投影（悬浮按钮、Tab Bar）
        static let elevated = Shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: 14)
    }

    // MARK: 动效

    enum Motion {
        /// 主弹性曲线
        static let snappy = Animation.spring(response: 0.4, dampingFraction: 0.7)
        /// 温和弹性（大范围位移）
        static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.82)
        /// Tab Bar 专用
        static let tab = Animation.spring(response: 0.35, dampingFraction: 0.72)
        /// 内容淡入
        static let fade = Animation.easeInOut(duration: 0.28)
        /// 列表交错入场
        static func stagger(_ index: Int, base: Animation = Motion.snappy) -> Animation {
            base.delay(Double(index) * 0.05)
        }
    }
}

// MARK: - 通用修饰器

extension View {

    /// 玻璃卡片（性能优先）：用半透明纯色 + 描边模拟，避免 `.ultraThinMaterial`
    /// 的实时模糊。material 在滚动/高频刷新时会让主线程持续做离屏渲染，
    /// iOS 16 上表现为掉帧与「页面闪烁」。
    func glassSurface(
        radius: CGFloat = DS.Radius.card,
        strokeOpacity: Double = 0.13
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DS.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        dynamicHairline().opacity(strokeOpacity),
                        lineWidth: 1
                    )
            )
    }

    /// 实心卡片（低对比背景，不使用材质，性能更好）
    func solidSurface(radius: CGFloat = DS.Radius.card) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(DS.bgSecondary)
        )
    }

    /// 设计规范阴影
    func dsShadow(_ shadow: DS.Shadow = .soft) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// 页面标准横向内边距
    func screenPadding() -> some View {
        self.padding(.horizontal, DS.Space.screen)
    }

    /// 列表交错入场：index 越大延迟越久，营造「瀑布入场」的节奏感
    func staggerAppear(_ index: Int) -> some View {
        modifier(StaggerAppearModifier(index: index))
    }
}

/// 交错入场实现：首帧透明 + 下移，出现时用 spring 归位
struct StaggerAppearModifier: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                guard !appeared else { return }
                withAnimation(DS.Motion.stagger(index)) {
                    appeared = true
                }
            }
    }
}
