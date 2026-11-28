//
//  StatRing.swift
//  GitVault
//
//  收藏库统计环形图 + 通用统计块。
//

import SwiftUI

struct StatRingSegment: Identifiable {
    let id = UUID()
    let value: Int
    let color: Color
    let label: String
}

struct StatRing: View {
    let segments: [StatRingSegment]
    var total: Int
    var size: CGFloat = 108
    var lineWidth: CGFloat = 12

    private var sum: Int { max(total, segments.reduce(0) { $0 + $1.value }) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DS.bgTertiary, lineWidth: lineWidth)

            ForEach(arcs.indices, id: \.self) { index in
                let arc = arcs[index]
                Circle()
                    .trim(from: arc.start, to: arc.end)
                    .stroke(
                        arc.color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 0) {
                Text("\(total)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
                Text("个仓库")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DS.textTertiary)
            }
        }
        .frame(width: size, height: size)
        .animation(DS.Motion.gentle, value: total)
    }

    private struct Arc {
        let start: CGFloat
        let end: CGFloat
        let color: Color
    }

    private var arcs: [Arc] {
        guard sum > 0 else { return [] }
        var result: [Arc] = []
        var cursor: CGFloat = 0
        for segment in segments where segment.value > 0 {
            let fraction = CGFloat(segment.value) / CGFloat(sum)
            // 留一点缝隙，环形更像分段刻度
            let gap: CGFloat = 0.008
            // 钳制到 0...1 且保证 end >= start，避免 trim 收到非法区间
            let start = min(max(cursor + gap / 2, 0), 1)
            let end = min(max(cursor + fraction - gap / 2, start), 1)
            if end > start {
                result.append(Arc(start: start, end: end, color: segment.color))
            }
            cursor += fraction
        }
        return result
    }
}

/// 小统计块（Profile / Vault 顶部复用）
struct StatBlock: View {
    let value: String
    let label: String
    var tint: Color = DS.textPrimary

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("环形统计") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        StatRing(
            segments: [
                .init(value: 12, color: MyMark.starred.tint, label: "收藏"),
                .init(value: 8, color: MyMark.inUse.tint, label: "在用"),
                .init(value: 5, color: MyMark.watching.tint, label: "观察"),
                .init(value: 3, color: MyMark.archived.tint, label: "归档")
            ],
            total: 28
        )
    }
}
