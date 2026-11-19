//
//  Logos.swift
//  GitVault
//
//  品牌图形。GBLogoMark 与 App 图标（Scripts/make_icon.js）造型完全对应：
//  猫耳圆环（Octocat 致敬 + 保险库转盘）+ 中心 fork 三节点（Git 分支语义）。
//

import SwiftUI

/// 猫耳圆环：极坐标采样，耳朵处半径按余弦外扩
struct CatEarRing: Shape {
    var earLift: CGFloat = 0.070
    var earHalf: CGFloat = 0.30
    /// 两只耳朵的角度（弧度，0 指向右侧，顺时针为正）
    var earAngles: [CGFloat] = [-2.55, -0.59]

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let base = min(rect.width, rect.height) / 2
        var path = Path()
        let steps = 240

        for step in 0...steps {
            let theta = CGFloat(step) / CGFloat(steps) * 2 * .pi
            var radius = base * 0.86

            for ear in earAngles {
                var delta = theta - ear
                // 归一化到 -π...π
                delta = atan2(sin(delta), cos(delta))
                if abs(delta) < earHalf {
                    radius += base * earLift * cos(delta / earHalf * .pi / 2)
                }
            }

            let point = CGPoint(
                x: center.x + cos(theta) * radius,
                y: center.y + sin(theta) * radius
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// fork 三节点：顶点 + 分叉点 + 左右两个子节点
struct ForkGlyph: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            Path { path in
                let top = CGPoint(x: size * 0.5, y: size * 0.20)
                let fork = CGPoint(x: size * 0.5, y: size * 0.52)
                let left = CGPoint(x: size * 0.24, y: size * 0.78)
                let right = CGPoint(x: size * 0.76, y: size * 0.78)
                path.move(to: top)
                path.addLine(to: fork)
                path.move(to: fork)
                path.addLine(to: left)
                path.move(to: fork)
                path.addLine(to: right)
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round, lineJoin: .round))

            node(size: size, x: 0.5, y: 0.20)
            node(size: size, x: 0.24, y: 0.78)
            node(size: size, x: 0.76, y: 0.78)
        }
        .frame(width: size, height: size)
    }

    private func node(size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: size * 0.20, height: size * 0.20)
            .offset(x: (x - 0.5) * size, y: (y - 0.5) * size)
    }
}

/// App 品牌标记（启动页 / 侧栏 / 登录页共用，与桌面图标同构）
struct GBLogoMark: View {
    var size: CGFloat = 72
    var glow: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(DS.logoBase)

            CatEarRing()
                .stroke(
                    DS.accentGradient,
                    style: StrokeStyle(lineWidth: size * 0.052, lineCap: .round)
                )
                .frame(width: size * 0.78, height: size * 0.78)

            ForkGlyph(size: size * 0.40)
        }
        .frame(width: size, height: size)
        .shadow(
            color: glow ? DS.accent.opacity(0.55) : .clear,
            radius: glow ? size * 0.28 : 0,
            x: 0,
            y: size * 0.10
        )
        .accessibilityLabel("GitVault")
    }
}

/// 项目封面：品牌渐变 + 右下角柔光 + 首字母水印
struct RepoCover: View {
    let initials: String
    let gradient: [Color]
    var cornerRadius: CGFloat = DS.Radius.cover
    var showsGlyph: Bool = true

    var body: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 90, height: 90)
                .blur(radius: 34)
                .offset(x: 34, y: 34)

            if showsGlyph {
                Text(initials)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview("品牌标记") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        VStack(spacing: 32) {
            GBLogoMark(size: 108)
            HStack(spacing: 20) {
                GBLogoMark(size: 52, glow: false)
                GBLogoMark(size: 40, glow: false)
            }
        }
    }
}
