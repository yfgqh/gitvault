//
//  LanguageBar.swift
//  GitVault
//
//  语言占比条：数据来自 /repos/{owner}/{repo}/languages，按字节占比渲染。
//

import SwiftUI

struct LanguageBar: View {
    let slices: [LanguageSlice]
    var height: CGFloat = 8

    private var normalized: [LanguageSlice] {
        // 只画占比 ≥1% 的语言，其余合并为「其他」
        let major = slices.filter { $0.percent >= 1 }
        let rest = slices.filter { $0.percent < 1 }.reduce(0) { $0 + $1.percent }
        return rest > 0 ? major + [LanguageSlice(name: "其他", percent: rest)] : major
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(normalized) { slice in
                        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                            .fill(color(for: slice.name))
                            .frame(width: Swift.max(2, geo.size.width * CGFloat(slice.percent / 100) - 2))
                    }
                }
                .frame(width: geo.size.width, alignment: .leading)
            }
            .frame(height: height)
            .clipped()

            ScrollView(.horizontal) {
                HStack(spacing: DS.Space.m) {
                    ForEach(normalized) { slice in
                        HStack(spacing: 5) {
                            LanguageDot(color: color(for: slice.name))
                            Text("\(slice.name) \(String(format: "%.1f", slice.percent))%")
                                .font(DS.Typo.caption)
                                .foregroundStyle(slice.name == "其他" ? DS.textTertiary : DS.textSecondary)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "语言构成：" + normalized.map { "\($0.name) \(Int($0.percent))%" }.joined(separator: "，")
        )
    }

    private func color(for name: String) -> Color {
        name == "其他" ? DS.bgTertiary : LanguagePalette.color(for: name)
    }
}

#Preview("语言占比") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        LanguageBar(slices: [
            LanguageSlice(name: "Swift", percent: 62.4),
            LanguageSlice(name: "Objective-C", percent: 21.1),
            LanguageSlice(name: "C", percent: 12.0),
            LanguageSlice(name: "Ruby", percent: 4.5)
        ])
        .padding()
    }
}
