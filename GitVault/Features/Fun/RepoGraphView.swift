//
//  RepoGraphView.swift
//  GitVault
//
//  项目结构图：以仓库为中心的放射状关系图（Canvas 绘制，无三方依赖）。
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
        let distance: CGFloat
    }

    private var centerTopics: [String] { Array(repo.topics.prefix(6)) }

    private var nodes: [Node] {
        var list: [Node] = [
            Node(id: "lang", title: repo.language, emoji: "◆", tint: LanguagePalette.color(for: repo.language), angle: -1.9, distance: 0.34),
            Node(id: "license", title: repo.license.title, emoji: "©", tint: repo.license.tint, angle: -1.1, distance: 0.34),
            Node(id: "stars", title: repo.starText, emoji: "★", tint: MyMark.starred.tint, angle: 0.4, distance: 0.36),
            Node(id: "category", title: repo.category.title, emoji: repo.category.emoji, tint: repo.category.tint, angle: 1.9, distance: 0.34)
        ]
        for (index, topic) in centerTopics.enumerated() {
            let angle = Double(index) / Double(max(centerTopics.count, 1)) * 2 * Double.pi + 0.9
            list.append(Node(id: "topic-\(topic)",
                             title: topic,
                             emoji: "#",
                             tint: DS.accentAlt,
                             angle: angle,
                             distance: 0.46))
        }
        return list
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Space.m) {
                GeometryReader { geo in
                    ZStack {
                        Canvas { context, size in
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            for node in nodes {
                                let point = position(of: node, in: size)
                                var path = Path()
                                path.move(to: center)
                                path.addLine(to: point)
                                context.stroke(path, with: .color(DS.separator), lineWidth: 1)
                            }
                            let rect = CGRect(x: center.x - 34, y: center.y - 34, width: 68, height: 68)
                            context.fill(Path(ellipseIn: rect), with: .color(DS.accent.opacity(0.18)))
                            context.stroke(Path(ellipseIn: rect), with: .color(DS.accent), lineWidth: 1.5)
                        }

                        ForEach(nodes) { node in
                            VStack(spacing: 1) {
                                Text(node.emoji).font(.system(size: 12))
                                Text(node.title)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(DS.textPrimary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 6)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 4)
                            .background(Capsule().fill(node.tint.opacity(0.16)))
                            .overlay(Capsule().strokeBorder(node.tint.opacity(0.5), lineWidth: 1))
                            .position(position(of: node, in: geo.size))
                        }

                        VStack(spacing: 1) {
                            Text(repo.name)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DS.textPrimary)
                                .lineLimit(1)
                            Text(repo.owner)
                                .font(.system(size: 8))
                                .foregroundStyle(DS.textTertiary)
                        }
                        .frame(width: 64)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                }
                .frame(height: 380)

                Text("这张图把一个项目拆成「语言 / 许可 / 热度 / 主题」四类关系，帮你判断它属于哪一支技术脉络。")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Space.l)

                Spacer(minLength: 0)
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

    private func position(of node: Node, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2 + CGFloat(cos(node.angle)) * size.width * node.distance,
            y: size.height / 2 + CGFloat(sin(node.angle)) * size.height * node.distance
        )
    }
}
