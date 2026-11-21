//
//  RepoGraphView.swift
//  GitVault
//
//  项目结构图：以仓库为中心的放射状关系图（Canvas 绘制，无三方依赖）。
//  布局要点：节点半径按「可用半径减去标签宽高」计算，避免胶囊被画布边缘裁掉；
//  整页可滚动，说明文字独立成块，不再与节点叠在一起。
//

import SwiftUI

struct RepoGraphView: View {
    let repo: ShowcaseRepo
    @Environment(\.dismiss) private var dismiss

    private struct Node: Identifiable {
        let id: String
        let title: String
        let emoji: String
        let tint: Color
        let angle: Double
        /// 相对可用半径的比例（0–1）
        let distance: CGFloat
    }

    private var topicNodes: [Node] {
        let topics = Array(repo.topics.prefix(6))
        return topics.enumerated().map { index, topic in
            let angle = Double(index) / Double(max(topics.count, 1)) * 2 * Double.pi + 0.55
            return Node(id: "topic-\(topic)", title: topic, emoji: "#",
                        tint: DS.accentAlt, angle: angle, distance: 0.96)
        }
    }

    private var coreNodes: [Node] {
        [
            Node(id: "lang", title: repo.language, emoji: "◆",
                 tint: LanguagePalette.color(for: repo.language), angle: -2.2, distance: 0.58),
            Node(id: "license", title: repo.license.title, emoji: "©",
                 tint: repo.license.tint, angle: -0.9, distance: 0.58),
            Node(id: "stars", title: repo.starText, emoji: "★",
                 tint: MyMark.starred.tint, angle: 0.6, distance: 0.58),
            Node(id: "category", title: repo.category.title, emoji: repo.category.emoji,
                 tint: repo.category.tint, angle: 2.2, distance: 0.58)
        ]
    }

    private var nodes: [Node] { coreNodes + topicNodes }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    canvas
                    legend
                    Text("这张图把一个项目拆成「语言 / 许可 / 热度 / 主题」四类关系，帮你判断它属于哪一支技术脉络。")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Space.s)
                }
                .padding(.horizontal, DS.Space.m)
                .padding(.bottom, DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("项目结构")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
        }
    }

    // MARK: 画布

    private var canvas: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // 标签最大宽 96、高约 26，留 12 的呼吸位
            let insetX: CGFloat = 60
            let insetY: CGFloat = 26
            let radiusX = max(size.width / 2 - insetX, 60)
            let radiusY = max(size.height / 2 - insetY, 60)

            ZStack {
                // 背景网格（同心圆），提供层次感
                ForEach([0.34, 0.62, 0.92], id: \.self) { ratio in
                    Ellipse()
                        .strokeBorder(DS.separator.opacity(0.5), lineWidth: 0.8)
                        .frame(width: radiusX * 2 * ratio, height: radiusY * 2 * ratio)
                        .position(center)
                }

                Canvas { context, _ in
                    for node in nodes {
                        let point = point(for: node, center: center, radiusX: radiusX, radiusY: radiusY)
                        var path = Path()
                        path.move(to: center)
                        path.addLine(to: point)
                        context.stroke(path, with: .color(DS.separator), lineWidth: 1)
                    }

                    let coreRect = CGRect(x: center.x - 38, y: center.y - 38, width: 76, height: 76)
                    context.fill(Path(ellipseIn: coreRect), with: .color(DS.accent.opacity(0.16)))
                    context.stroke(Path(ellipseIn: coreRect), with: .color(DS.accent), lineWidth: 1.5)
                }

                ForEach(nodes) { node in
                    nodeChip(node)
                        .position(point(for: node, center: center, radiusX: radiusX, radiusY: radiusY))
                }

                VStack(spacing: 1) {
                    Text(repo.name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(repo.owner)
                        .font(.system(size: 8))
                        .foregroundStyle(DS.textTertiary)
                        .lineLimit(1)
                }
                .frame(width: 68)
                .position(center)
            }
        }
        .frame(height: 480)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.cardLarge, style: .continuous)
                .fill(DS.bgSecondary.opacity(0.5))
        )
        .clipped()
    }

    private func nodeChip(_ node: Node) -> some View {
        HStack(spacing: 4) {
            Text(node.emoji).font(.system(size: 10))
            Text(node.title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(DS.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: 100)
        .background(Capsule().fill(node.tint.opacity(0.16)))
        .overlay(Capsule().strokeBorder(node.tint.opacity(0.5), lineWidth: 1))
    }

    private func point(for node: Node,
                       center: CGPoint,
                       radiusX: CGFloat,
                       radiusY: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(cos(node.angle)) * radiusX * node.distance,
            y: center.y + CGFloat(sin(node.angle)) * radiusY * node.distance
        )
    }

    // MARK: 图例

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendRow(color: DS.accentAlt, text: "主题标签（#）")
            legendRow(color: LanguagePalette.color(for: repo.language), text: "主语言")
            legendRow(color: repo.license.tint, text: "开源许可")
            legendRow(color: MyMark.starred.tint, text: "社区热度")
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(DS.textSecondary)
        }
    }
}
