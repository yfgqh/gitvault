//
//  AuthorView.swift
//  GitVault
//
//  作者页：看这个 owner 的其他高星仓库。
//

import SwiftUI

@MainActor
final class AuthorViewModel: ObservableObject {
    @Published var items: [ShowcaseRepo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var didLoad = false

    func loadIfNeeded(login: String) async {
        guard !didLoad else { return }
        didLoad = true
        isLoading = true
        defer { isLoading = false }
        do {
            let dtos = try await GitHubExtrasService.shared.repositories(by: login)
            items = dtos
                .map(ShowcaseRepo.init(dto:))
                .sorted { $0.stars > $1.stars }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AuthorView: View {
    let login: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AuthorViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    if vm.isLoading {
                        ProgressView("正在读取 \(login) 的仓库…")
                            .tint(DS.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, DS.Space.l)
                    } else if let error = vm.errorMessage {
                        VStack(spacing: 6) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 26))
                                .foregroundStyle(DS.textTertiary)
                            Text(error)
                                .font(DS.Typo.caption)
                                .foregroundStyle(DS.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Space.l)
                    } else if vm.items.isEmpty {
                        Text("这个作者没有公开仓库")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, DS.Space.l)
                    } else {
                        Text("\(login) · \(vm.items.count) 个仓库")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textTertiary)
                            .padding(.horizontal, DS.Space.s)

                        ForEach(vm.items) { repo in
                            NavigationLink(value: repo) {
                                row(repo)
                            }
                            .buttonStyle(.springPressCard)
                        }
                    }
                }
                .padding(DS.Space.screen)
            }
            .background(DS.bgPrimary)
            .navigationTitle(login)
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
            .task { await vm.loadIfNeeded(login: login) }
        }
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
