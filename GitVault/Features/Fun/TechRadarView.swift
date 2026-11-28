//
//  TechRadarView.swift
//  GitVault
//
//  技术雷达：基于本地全量库，统计近半年新项目的主题热度与语言分布。
//

import SwiftUI

struct TechRadarView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false

    private var recentRepos: [ShowcaseRepo] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -6, to: .now) ?? .now
        return env.allRepos.repos.filter { ($0.createdAt ?? .distantPast) >= cutoff }
    }

    private var topicRanking: [(topic: String, count: Int)] {
        var counter: [String: Int] = [:]
        for repo in recentRepos {
            for topic in repo.topics where !topic.isEmpty {
                counter[topic.lowercased(), default: 0] += 1
            }
        }
        return counter
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { (topic: $0.key, count: $0.value) }
    }

    private var languageRanking: [(name: String, count: Int)] {
        var counter: [String: Int] = [:]
        for repo in recentRepos where repo.language != "未知" {
            counter[repo.language, default: 0] += 1
        }
        return counter
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { (name: $0.key, count: $0.value) }
    }

    private var categoryRanking: [(category: RepoCategory, count: Int)] {
        var counter: [RepoCategory: Int] = [:]
        for repo in recentRepos {
            counter[repo.category, default: 0] += 1
        }
        return counter
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { (category: $0.key, count: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    if recentRepos.isEmpty {
                        emptyState
                    } else {
                        headline
                        section(title: "上升最快的主题", rows: topicRanking.map { ("#" + $0.topic, $0.count) }, tint: DS.accent)
                        section(title: "主力语言", rows: languageRanking.map { ($0.name, $0.count) }, tint: DS.accentAlt)
                        categorySection
                        footnote
                    }
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("技术雷达")
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

    private var emptyState: some View {
        VStack(spacing: DS.Space.s) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 30))
                .foregroundStyle(DS.textTertiary)
            Text("需要一点本地数据")
                .font(DS.Typo.body)
                .foregroundStyle(DS.textSecondary)
            Text("雷达基于已缓存的仓库计算。先去「分类」页多逛几次，或点下面的按钮抓一批。")
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.tap()
                isLoading = true
                Task {
                    for _ in 0..<3 { await env.allRepos.refreshStep() }
                    isLoading = false
                }
            } label: {
                HStack(spacing: 6) {
                    if isLoading { ProgressView().scaleEffect(0.7).tint(.white) }
                    Text(isLoading ? "正在抓取…" : "抓取一批数据")
                        .font(DS.Typo.caption)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(DS.accent))
            }
            .buttonStyle(.springPress)
            .disabled(isLoading)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Space.l)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: NSLocalizedString("近 6 个月新增的 %d 个项目", comment: ""), recentRepos.count))
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)
            Text("按主题与语言统计，样本来自本地缓存的全量库")
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
    }

    private func section(title: String,
                         rows: [(String, Int)],
                         tint: Color) -> some View {
        let maxValue = rows.map { $0.1 }.max() ?? 1
        return VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(title)
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.0)
                            .font(.system(size: 11))
                            .foregroundStyle(DS.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(row.1)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.textTertiary)
                    }
                    ProgressView(value: Double(row.1), total: Double(max(maxValue, 1)))
                        .progressViewStyle(.linear)
                        .tint(tint)
                        .scaleEffect(x: 1, y: 0.6, anchor: .center)
                }
            }
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("主题分布")
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)

            HStack(spacing: DS.Space.s) {
                ForEach(Array(categoryRanking.enumerated()), id: \.offset) { _, row in
                    VStack(spacing: 4) {
                        Text(row.category.emoji).font(.system(size: 16))
                        Text("\(row.count)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.textPrimary)
                        Text(row.category.title)
                            .font(.system(size: 8))
                            .foregroundStyle(DS.textTertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(row.category.tint.opacity(0.12))
                    )
                }
            }
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    private var footnote: some View {
        Text("说明：GitHub 不提供历史星标数据，这里的「热度」是近半年新增项目的主题出现频次，反映的是新项目在往哪些方向聚集，而不是涨幅。")
            .font(.system(size: 10))
            .foregroundStyle(DS.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
