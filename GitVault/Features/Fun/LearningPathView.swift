//
//  LearningPathView.swift
//  GitVault
//
//  学习路径：把一个主题的项目按「入门 / 进阶 / 深入」分档，形成可执行的清单。
//

import SwiftUI

@MainActor
final class LearningPathViewModel: ObservableObject {
    @Published var items: [ShowcaseRepo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var didLoad = false
    private let api: any GitHubAPI

    init(api: any GitHubAPI = GitHubService.shared) {
        self.api = api
    }

    func loadIfNeeded(category: RepoCategory, fallback: [ShowcaseRepo]) async {
        guard !didLoad else { return }
        didLoad = true

        if fallback.count >= 6 {
            items = fallback
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await api.fetchCategoryPage(category, page: 1, perPage: 100)
            items = page.items.map(ShowcaseRepo.init(dto:))
        } catch is CancellationError {
            return
        } catch {
            items = fallback
            errorMessage = items.isEmpty ? error.localizedDescription : nil
        }
    }

    func stages() -> [(title: String, subtitle: String, items: [ShowcaseRepo])] {
        let beginner = items.filter { $0.stars < 5_000 }.sorted { $0.stars > $1.stars }.prefix(6).map { $0 }
        let intermediate = items.filter { (5_000..<20_000).contains($0.stars) }.sorted { $0.stars > $1.stars }.prefix(6).map { $0 }
        let advanced = items.filter { $0.stars >= 20_000 }.sorted { $0.stars > $1.stars }.prefix(6).map { $0 }

        return [
            ("入门：先跑起来", "文档友好、上手成本低，适合先建立直觉", beginner),
            ("进阶：读源码", "社区成熟、结构完整，适合研究实现", intermediate),
            ("深入：工业级参考", "被广泛使用，适合对照自己的架构", advanced)
        ]
    }
}

struct LearningPathView: View {
    let category: RepoCategory

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = LearningPathViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    header

                    if vm.isLoading {
                        ProgressView("正在准备清单…")
                            .tint(DS.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Space.l)
                    } else if vm.items.isEmpty {
                        Text("这个主题暂时没有足够的数据，先去分类页加载一批。")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textTertiary)
                            .padding(.vertical, DS.Space.l)
                    } else {
                        ForEach(Array(vm.stages().enumerated()), id: \.offset) { index, stage in
                            stageSection(index: index + 1, stage: stage)
                        }
                    }
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("学习路径")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
            .task {
                await vm.loadIfNeeded(category: category,
                                      fallback: env.allRepos.items(in: category))
            }
        }
    }

    private var header: some View {
        HStack(spacing: DS.Space.m) {
            ZStack {
                Circle().fill(category.tint.opacity(0.14)).frame(width: 46, height: 46)
                Text(category.emoji).font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(DS.Typo.cardTitle)
                    .foregroundStyle(DS.textPrimary)
                Text(String(format: NSLocalizedString("按难度分三档，共 %d 个候选", comment: ""), vm.items.count))
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    private func stageSection(index: Int,
                              stage: (title: String, subtitle: String, items: [ShowcaseRepo])) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: 8) {
                Text("\(index)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(category.tint))

                VStack(alignment: .leading, spacing: 1) {
                    Text(stage.title)
                        .font(DS.Typo.headline)
                        .foregroundStyle(DS.textPrimary)
                    Text(stage.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textTertiary)
                }
                Spacer(minLength: 0)
            }

            if stage.items.isEmpty {
                Text("这一档暂无合适项目")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textTertiary)
                    .padding(.leading, 28)
            } else {
                VStack(spacing: DS.Space.s) {
                    ForEach(stage.items) { repo in
                        NavigationLink(value: repo) {
                            row(repo)
                        }
                        .buttonStyle(.springPressCard)
                    }
                }
            }
        }
    }

    private func row(_ repo: ShowcaseRepo) -> some View {
        HStack(spacing: DS.Space.s) {
            AvatarView(url: repo.avatarURL,
                       size: 30,
                       initials: repo.initials,
                       gradient: repo.gradient)

            VStack(alignment: .leading, spacing: 1) {
                Text(repo.name)
                    .font(DS.Typo.bodySmall)
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(1)
                Text(repo.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(repo.starText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DS.textTertiary)
        }
        .padding(DS.Space.s)
        .glassSurface(radius: DS.Radius.button)
    }
}
