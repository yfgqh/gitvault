//
//  MyReposView.swift
//  GitVault
//
//  「我的」里的仓库列表：GET /user/repos（按最近更新排序）。
//

import SwiftUI

@MainActor
final class MyReposViewModel: ObservableObject {
    @Published var items: [ShowcaseRepo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var didLoad = false

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await reload()
    }

    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let dtos = try await GitHubExtrasService.shared.myRepositories()
            items = dtos.map(ShowcaseRepo.init(dto:))
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MyReposView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = MyReposViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isSignedIn {
                    signInHint
                } else if vm.isLoading && vm.items.isEmpty {
                    ProgressView("正在读取你的仓库…")
                        .tint(DS.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage, vm.items.isEmpty {
                    VStack(spacing: DS.Space.s) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 26))
                            .foregroundStyle(DS.warning)
                        Text(error)
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("重试") { Task { await vm.reload() } }
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.accent)
                    }
                    .padding(DS.Space.l)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.items.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 26))
                            .foregroundStyle(DS.textTertiary)
                        Text("这个账号还没有公开仓库")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: DS.Space.s) {
                            ForEach(vm.items) { repo in
                                NavigationLink(value: repo) {
                                    row(repo)
                                }
                                .buttonStyle(.springPressCard)
                            }
                        }
                        .padding(.horizontal, DS.Space.screen)
                        .padding(.vertical, DS.Space.m)
                    }
                }
            }
            .background(DS.bgPrimary)
            .navigationTitle("我的仓库")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ShowcaseRepo.self) { repo in
                RepoDetailView(repo: repo)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
            .task { await vm.loadIfNeeded() }
            .refreshable { await vm.reload() }
        }
    }

    private var signInHint: some View {
        VStack(spacing: DS.Space.s) {
            GBLogoMark(size: 52, glow: false)
            Text("登录 GitHub 后查看你的仓库")
                .font(DS.Typo.bodySmall)
                .foregroundStyle(DS.textSecondary)
            Text("在「我的 → GitHub 登录」用访问令牌登录即可")
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ repo: ShowcaseRepo) -> some View {
        HStack(spacing: DS.Space.s) {
            AvatarView(url: repo.avatarURL,
                       size: 34,
                       initials: repo.initials,
                       gradient: repo.gradient)

            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(DS.Typo.body)
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(1)
                Text(repo.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(MyMark.starred.tint)
                Text(repo.starText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.textSecondary)
            }
        }
        .padding(DS.Space.m)
        .glassSurface(radius: DS.Radius.button)
    }
}
