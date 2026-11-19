//
//  VaultView.swift
//  GitVault
//
//  收藏库（iOS 16 兼容）：JSON 持久化 + 环形统计 + 文件夹 + 左滑 + 拖拽排序 + 导出。
//

import SwiftUI

struct VaultView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var vault: VaultStore

    @State private var activeMark: MyMark?
    @State private var editMode: EditMode = .inactive
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var exportFile: ExportFile?
    @State private var moveTarget: VaultItem?

    private var filtered: [VaultItem] {
        guard let activeMark else { return vault.items }
        return vault.items.filter { $0.mark == activeMark }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, DS.Space.screen)
                    .padding(.top, DS.Space.s)
                    .padding(.bottom, DS.Space.s)

                markFilter
                    .padding(.bottom, DS.Space.s)

                list
            }
            .background(DS.bgPrimary)
            .navigationBarHidden(true)
            .alert("新建文件夹", isPresented: $showingNewFolder) {
                TextField("文件夹名称", text: $newFolderName)
                Button("取消", role: .cancel) { newFolderName = "" }
                Button("创建") {
                    if let folder = vault.createFolder(name: newFolderName) {
                        Haptics.success()
                        env.show("已创建文件夹：\(folder.name)", kind: .success)
                    }
                    newFolderName = ""
                }
            } message: {
                Text("用来给你的收藏分组，例如「AI 工具箱」。")
            }
            .confirmationDialog("移入文件夹", isPresented: Binding(
                get: { moveTarget != nil },
                set: { if !$0 { moveTarget = nil } }
            ), titleVisibility: .visible) {
                Button("不分组") { move(moveTarget, to: nil) }
                ForEach(vault.folders) { folder in
                    Button(folder.emoji + " " + folder.name) { move(moveTarget, to: folder.name) }
                }
                Button("取消", role: .cancel) { moveTarget = nil }
            }
            .sheet(item: $exportFile) { file in
                ShareSheet(items: [file.url])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("你的私有空间")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textTertiary)
                Text("收藏库")
                    .font(DS.Typo.largeTitle)
                    .foregroundStyle(DS.textPrimary)
            }

            Spacer()

            Menu {
                Button {
                    showingNewFolder = true
                } label: {
                    Label("新建文件夹", systemImage: "folder.badge.plus")
                }
                Divider()
                Button {
                    export(.json)
                } label: {
                    Label("导出 JSON", systemImage: "curlybraces")
                }
                Button {
                    export(.markdown)
                } label: {
                    Label("导出 Markdown", systemImage: "doc.plaintext")
                }
                Divider()
                Button(editMode.isEditing ? "完成排序" : "拖拽排序") {
                    withAnimation(DS.Motion.snappy) {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.textSecondary)
            }
            .accessibilityLabel("更多操作")
        }
    }

    // MARK: 统计 + 标记筛选

    private var markFilter: some View {
        VStack(spacing: DS.Space.m) {
            statsCard
                .padding(.horizontal, DS.Space.screen)

            ScrollView(.horizontal) {
                HStack(spacing: DS.Space.s) {
                    FilterChip(title: "全部", isActive: activeMark == nil) {
                        withAnimation(DS.Motion.snappy) { activeMark = nil }
                    }
                    ForEach(MyMark.allCases) { mark in
                        FilterChip(title: mark.title, emoji: mark.emoji, isActive: activeMark == mark) {
                            withAnimation(DS.Motion.snappy) {
                                activeMark = (activeMark == mark) ? nil : mark
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Space.screen)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var statsCard: some View {
        HStack(spacing: DS.Space.l) {
            StatRing(
                segments: [
                    .init(value: vault.count(.starred), color: MyMark.starred.tint, label: "收藏"),
                    .init(value: vault.count(.inUse), color: MyMark.inUse.tint, label: "在用"),
                    .init(value: vault.count(.watching), color: MyMark.watching.tint, label: "观察"),
                    .init(value: vault.count(.archived), color: MyMark.archived.tint, label: "归档")
                ],
                total: vault.items.count
            )

            VStack(alignment: .leading, spacing: DS.Space.s) {
                ForEach(MyMark.allCases) { mark in
                    HStack(spacing: 8) {
                        Circle().fill(mark.tint).frame(width: 7, height: 7)
                        Text(mark.emoji + " " + mark.title)
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textSecondary)
                        Spacer(minLength: 4)
                        Text("\(vault.count(mark))")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textPrimary)
                    }
                }
            }
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    // MARK: 列表

    private var list: some View {
        List {
            if !vault.folders.isEmpty {
                Section {
                    ForEach(vault.folders) { folder in
                        folderRow(folder)
                    }
                } header: {
                    sectionHeader("我的文件夹", detail: "\(vault.folders.count) 个")
                }
            }

            Section {
                if filtered.isEmpty {
                    emptyRow
                } else {
                    entryRows
                }
            } header: {
                sectionHeader("收藏项目", detail: "\(filtered.count) 个")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
        .animation(DS.Motion.snappy, value: filtered.count)
    }

    @ViewBuilder
    private var entryRows: some View {
        if activeMark == nil {
            ForEach(filtered) { item in
                entryRow(item)
            }
            .onMove { from, to in
                vault.move(fromOffsets: from, toOffset: to, in: filtered)
                Haptics.tap()
            }
        } else {
            ForEach(filtered) { item in
                entryRow(item)
            }
        }
    }

    private func entryRow(_ item: VaultItem) -> some View {
        VaultRow(item: item)
            .listRowInsets(EdgeInsets(top: 4, leading: DS.Space.screen, bottom: 4, trailing: DS.Space.screen))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    vault.remove(id: item.repoID)
                    Haptics.warning()
                    env.show("已删除：\(item.name)", kind: .info)
                } label: {
                    Label("删除", systemImage: "trash")
                }

                Button {
                    vault.setMark(id: item.repoID, to: .archived)
                    Haptics.tap()
                } label: {
                    Label("归档", systemImage: "archivebox")
                }
                .tint(.orange)

                Button {
                    vault.setMark(id: item.repoID, to: .inUse)
                    Haptics.success()
                } label: {
                    Label("在用", systemImage: "hammer")
                }
                .tint(DS.accent)
            }
            .swipeActions(edge: .leading) {
                Button {
                    vault.setMark(id: item.repoID, to: .watching)
                    Haptics.tap()
                } label: {
                    Label("观察", systemImage: "eye")
                }
                .tint(Color(hex: 0x6EE7FF))

                Button {
                    moveTarget = item
                } label: {
                    Label("分组", systemImage: "folder")
                }
                .tint(Color(hex: 0xA66CFF))
            }
            .contextMenu {
                ForEach(MyMark.allCases) { mark in
                    Button {
                        vault.setMark(id: item.repoID, to: mark)
                        Haptics.tap()
                    } label: {
                        Label("标为\(mark.title)", systemImage: mark.symbol)
                    }
                }
                Button {
                    moveTarget = item
                } label: {
                    Label("移入文件夹", systemImage: "folder")
                }
            }
    }

    private func folderRow(_ folder: VaultFolderItem) -> some View {
        HStack(spacing: DS.Space.m) {
            Text(folder.emoji)
                .font(.system(size: 18))
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(DS.bgTertiary)
                )

            Text(folder.name)
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)

            Spacer()

            Text("\(vault.items(inFolder: folder.name).count)")
                .font(DS.Typo.caption)
                .foregroundStyle(DS.textTertiary)
        }
        .padding(DS.Space.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.bgSecondary)
        )
        .listRowInsets(EdgeInsets(top: 4, leading: DS.Space.screen, bottom: 4, trailing: DS.Space.screen))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions {
            Button(role: .destructive) {
                vault.deleteFolder(folder)
                Haptics.warning()
            } label: {
                Label("删除文件夹", systemImage: "trash")
            }
        }
    }

    private var emptyRow: some View {
        EmptyStateView(
            symbol: "bookmark",
            title: activeMark == nil ? "收藏库还是空的" : "这个标记下还没有项目",
            message: activeMark == nil
                ? "在发现页看到心动的项目，点一下书签就会出现在这里"
                : "切换标记或去发现页补充几个"
        )
        .padding(.vertical, DS.Space.l)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        HStack {
            Text(title)
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)
            Spacer()
            Text(detail)
                .font(DS.Typo.caption)
                .foregroundStyle(DS.textTertiary)
        }
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 8, leading: DS.Space.screen, bottom: 4, trailing: DS.Space.screen))
    }

    // MARK: 动作

    private func move(_ item: VaultItem?, to folder: String?) {
        guard let item else { return }
        vault.assign(id: item.repoID, to: folder)
        moveTarget = nil
        Haptics.success()
        env.show(folder.map { "已移入 \($0)" } ?? "已取消分组", kind: .success)
    }

    private func export(_ format: VaultStore.ExportFormat) {
        do {
            let url = try vault.export(format)
            exportFile = ExportFile(url: url, title: "导出 \(format.displayName)")
            Haptics.success()
        } catch {
            env.show("导出失败：\(error.localizedDescription)", kind: .warning)
        }
    }
}

/// 收藏行
struct VaultRow: View {
    let item: VaultItem

    var body: some View {
        HStack(spacing: DS.Space.m) {
            AvatarView(
                url: item.avatarURL.flatMap { URL(string: $0) },
                size: 46,
                initials: String(item.owner.prefix(1)).uppercased()
                    + String(item.name.prefix(1)).uppercased(),
                gradient: item.category.gradient
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(DS.Typo.headline)
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(1)
                    TagChip(text: item.mark.title, tint: item.mark.tint, compact: true)
                    if let folder = item.folderName {
                        TagChip(text: folder, systemImage: "folder", tint: DS.textTertiary, compact: true)
                    }
                }
                Text(item.summary)
                    .font(DS.Typo.captionRegular)
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("★ \(ShowcaseRepo.compact(item.stars))")
                    .font(DS.Typo.micro)
                    .foregroundStyle(DS.textTertiary)
                Text(item.category.emoji)
                    .font(.system(size: 11))
            }
        }
        .padding(DS.Space.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .strokeBorder(DS.separator, lineWidth: 1)
        )
    }
}

#Preview("收藏库") {
    VaultView()
        .environmentObject(AppEnvironment.live())
        .environmentObject(AuthStore())
        .environmentObject(VaultStore(fileName: "preview-vault.json"))
}
