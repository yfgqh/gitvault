//
//  CollectionMapView.swift
//  GitVault
//
//  收藏地图：按主题聚合的气泡图（确定性布局，不用力导向，滚动不掉帧）。
//

import SwiftUI

struct CollectionMapView: View {
    @EnvironmentObject private var vault: VaultStore
    @Environment(\.dismiss) private var dismiss

    private struct Bubble: Identifiable {
        let id: String
        let title: String
        let emoji: String
        let count: Int
        let tint: Color
        let position: CGPoint
        let radius: CGFloat
    }

    private var bubbles: [Bubble] {
        let grouped = Dictionary(grouping: vault.items, by: { $0.category })
        let maxCount = max(grouped.values.map { $0.count }.max() ?? 1, 1)
        let total = max(grouped.count, 1)

        return grouped.enumerated().map { index, pair in
            let angle = Double(index) / Double(total) * 2 * Double.pi - Double.pi / 2
            let distance = 0.30 + 0.06 * Double(index % 2)
            let ratio = CGFloat(pair.value.count) / CGFloat(maxCount)
            return Bubble(
                id: pair.key.rawValue,
                title: pair.key.title,
                emoji: pair.key.emoji,
                count: pair.value.count,
                tint: pair.key.tint,
                position: CGPoint(x: 0.5 + CGFloat(cos(angle)) * distance,
                                  y: 0.5 + CGFloat(sin(angle)) * distance),
                radius: 26 + ratio * 34
            )
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Space.m) {
                GeometryReader { geo in
                    ZStack {
                        Canvas { context, size in
                            // 连线
                            for bubble in bubbles {
                                var path = Path()
                                path.move(to: CGPoint(x: size.width / 2, y: size.height / 2))
                                path.addLine(to: CGPoint(x: bubble.position.x * size.width,
                                                         y: bubble.position.y * size.height))
                                context.stroke(path, with: .color(DS.separator), lineWidth: 1)
                            }
                            // 中心
                            let centerRect = CGRect(x: size.width / 2 - 26, y: size.height / 2 - 26,
                                                    width: 52, height: 52)
                            context.fill(Path(ellipseIn: centerRect), with: .color(DS.accent.opacity(0.16)))
                            context.stroke(Path(ellipseIn: centerRect), with: .color(DS.accent), lineWidth: 1.5)
                        }

                        ForEach(bubbles) { bubble in
                            VStack(spacing: 2) {
                                Text(bubble.emoji).font(.system(size: 16))
                                Text("\(bubble.count)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(DS.textPrimary)
                            }
                            .frame(width: bubble.radius * 2, height: bubble.radius * 2)
                            .background(Circle().fill(bubble.tint.opacity(0.16)))
                            .overlay(Circle().strokeBorder(bubble.tint.opacity(0.55), lineWidth: 1))
                            .position(x: bubble.position.x * geo.size.width,
                                      y: bubble.position.y * geo.size.height)
                        }

                        VStack(spacing: 1) {
                            Text("\(vault.items.count)")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(DS.textPrimary)
                            Text("总数")
                                .font(.system(size: 8))
                                .foregroundStyle(DS.textTertiary)
                        }
                    }
                }
                .frame(height: 360)

                if bubbles.isEmpty {
                    Text("收藏之后，这里会按主题长出一片星图")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.textTertiary)
                } else {
                    ScrollView {
                        VStack(spacing: DS.Space.s) {
                            ForEach(bubbles) { bubble in
                                HStack(spacing: DS.Space.s) {
                                    Circle().fill(bubble.tint).frame(width: 8, height: 8)
                                    Text("\(bubble.emoji) \(bubble.title)")
                                        .font(DS.Typo.caption)
                                        .foregroundStyle(DS.textSecondary)
                                    Spacer()
                                    Text("\(bubble.count) 个")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(DS.textTertiary)
                                }
                                .padding(.horizontal, DS.Space.m)
                            }
                        }
                        .padding(.bottom, DS.Space.l)
                    }
                }
            }
            .background(DS.bgPrimary)
            .navigationTitle("收藏地图")
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
}
