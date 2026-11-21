//
//  FolderDetailView.swift
//  GitVault
//
//  文件夹详情：查看某个分组内的收藏，支持直接移出或打开详情。
//

import SwiftUI

struct FolderDetailView: View {
    let folder: VaultFolderItem

    @EnvironmentObject private var vault: VaultStore
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    private var items: [VaultItem] {
        vault.items(inFolder: folder.name)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DS.Space.s) {
                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 30))
                                .foregroundStyle(DS.textTertiary)
                            Text("这个文件夹还是空的")
                                .font(DS.Typo.bodySmall)
                                .foregroundStyle(DS.textSecondary)
                            Text("在收藏里长按项目 → 移入文件夹")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Space.l)
                    } else {
                        ForEach(items) { item in
                            NavigationLink(value: ShowcaseRepo(entry: item)) {
                                VaultRow(item: item)
                            }
                            .buttonStyle(.springPressCard)
                            .contextMenu {
                                Button {
                                    vault.assign(id: item.repoID, to: nil)
                                    env.show("已移出 \(folder.name)", kind: .success)
                                } label: {
                                    Label("移出文件夹", systemImage: "folder.badge.minus")
                                }
                                Button(role: .destructive) {
                                    vault.remove(id: item.repoID)
                                    env.show("已从收藏移除", kind: .warning)
                                } label: {
                                    Label("从收藏移除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Space.screen)
                .padding(.vertical, DS.Space.m)
            }
            .background(DS.bgPrimary)
            .navigationTitle(folder.emoji + " " + folder.name)
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
        }
    }
}
