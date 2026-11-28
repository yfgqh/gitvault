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
    /// 在「移入文件夹」里点了「新建文件夹」时记住要移动的项目
    @State private var pendingMoveItem: VaultItem?
    /// 正在编辑笔记的项目
    @State private var noteItem: VaultItem?
    @State private var noteDraft = ""
    @State private var batchProgress: String?
    @State private var openFolder: VaultFolderItem?
    @State private var exportFile: ExportFile?
    @State private var moveTarget: VaultItem?

    /// 主列表只显示「未分组」的项目；已归入文件夹的项目只在文件夹里出现
    private var filtered: [VaultItem] {
        var list = vault.items.filter { $0.folderName == nil }
        if let activeMark {
            list = list.filter { $0.mark == activeMark }
        }
        return list
    }

    private var groupedCount: Int {
        vault.items.filter { $0.folderName != nil }.count
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
                Button("取消", role: .cancel) {
                    newFolderName = ""
                    pendingMoveItem = nil
                }
                Button("创建") {
                    if let folder = vault.createFolder(name: newFolderName) {
                        // 如果是从「移入文件夹」里创建的，直接把这个项目放进去
                        if let item = pendingMoveItem {
                            vault.assign(id: item.repoID, to: folder.name)
                            env.show(String(format: NSLocalizedString("已移入 %@", comment: ""), folder.name), kind: .success)
                        } else {
                            env.show(String(format: NSLocalizedString("已创建文件夹：%@", comment: ""), folder.name), kind: .success)
                        }
                        Haptics.success()
                    }
                    pendingMoveItem = nil
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
                Divider()
                Button {
                    pendingMoveItem = moveTarget
                    moveTarget = nil
                    newFolderName = ""
                    // 稍等弹窗关闭再弹输入框，避免 iOS 16 上两个弹层打架
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showingNewFolder = true
                    }
                } label: {
                    Label("新建文件夹…", systemImage: "folder.badge.plus")
                }
                Button("取消", role: .cancel) { moveTarget = nil }
            }
            .alert("收藏笔记", isPresented: Binding(
                get: { noteItem != nil },
                set: { if !$0 { noteItem = nil } }
            )) {
                TextField("为什么收藏它？", text: $noteDraft, axis: .vertical)
                Button("取消", role: .cancel) { noteItem = nil; noteDraft = "" }
                Button("保存") {
                    if let item = noteItem {
                        vault.updateNote(id: item.repoID, note: noteDraft)
                        env.show("笔记已保存", kind: .success)
                    }
                    noteItem = nil
                    noteDraft = ""
                }
            } message: {
                Text("笔记会随收藏一起导出，帮助你半年后想起当初为什么存它。")
            }
            .sheet(item: $openFolder) { folder in
                FolderDetailView(folder: folder)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $exportFile) { file in
                ShareSheet(items: [file.url])
                    .presentationDetents([.medium, .large])
            }
            .navigationDestination(for: ShowcaseRepo.self) { repo in
                RepoDetailView(repo: repo)
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
                Button {
                Task { await batchStar() }
            } label: {
                Label("批量星标（Pro）", systemImage: "star.square.on.square")
            }
            Button {
                Task { await batchFork() }
            } label: {
                Label("批量 Fork（Pro）", systemImage: "arrow.triangle.branch")
            }
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

            // 毛毛虫下划线：手指划多少，下划线就跟多少
            CaterpillarSegmented(titles: markFilterTitles, selection: markFilterIndex)
                .padding(.horizontal, DS.Space.screen)
        }
    }

    private var markFilterTitles: [String] {
        [NSLocalizedString("全部", comment: "")] + MyMark.allCases.map { $0.title }
    }

    private var markFilterIndex: Binding<Int> {
        Binding(
            get: {
                guard let active = activeMark,
                      let index = MyMark.allCases.firstIndex(of: active) else { return 0 }
                return index + 1
            },
            set: { newValue in
                if newValue == 0 {
                    activeMark = nil
                } else if MyMark.allCases.indices.contains(newValue - 1) {
                    activeMark = MyMark.allCases[newValue - 1]
                }
            }
        )
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
                sectionHeader("未分组项目",
                              detail: groupedCount > 0
                                ? "\(filtered.count) 个 · \(groupedCount) 个已归入文件夹"
                                : "\(filtered.count) 个")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
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
        NavigationLink(value: ShowcaseRepo(entry: item)) {
            VStack(alignment: .leading, spacing: 6) {
                VaultRow(item: item)
                if let note = item.note, !note.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 8))
                        Text(note)
                            .font(.system(size: 10))
                            .lineLimit(2)
                    }
                    .foregroundStyle(DS.textTertiary)
                    .padding(.leading, 56)
                }
            }
        }
        .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 4, leading: DS.Space.screen, bottom: 4, trailing: DS.Space.screen))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    vault.remove(id: item.repoID)
                    Haptics.warning()
                    env.show(String(format: NSLocalizedString("已删除：%@", comment: ""), item.name), kind: .info)
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
                        Label(String(format: NSLocalizedString("标为 %@", comment: ""), mark.title), systemImage: mark.symbol)
                    }
                }
                Button {
                    moveTarget = item
                } label: {
                    Label("移入文件夹", systemImage: "folder")
                }
                Button {
                    noteItem = item
                    noteDraft = item.note ?? ""
                } label: {
                    Label(item.note == nil ? "添加笔记" : "编辑笔记", systemImage: "square.and.pencil")
                }
                Button {
                    if let url = ShareVaultHTML.writeFile(items: [item], title: item.name) {
                        exportFile = ExportFile(url: url, title: item.name)
                    }
                } label: {
                    Label("分享为 HTML", systemImage: "square.and.arrow.up")
                }
            }
    }

    // MARK: 批量操作

    private func batchStar() async {
        guard env.pro.hasFullAccess else {
            env.show("批量操作是 Pro 功能（当前限时免费试用中，请先解锁）", kind: .warning)
            return
        }
        guard env.auth.isSignedIn else {
            env.show("请先登录 GitHub", kind: .warning)
            return
        }
        let targets = Array(vault.items.prefix(20))
        guard !targets.isEmpty else { return }

        var done = 0
        for item in targets {
            batchProgress = "\(done)/\(targets.count)"
            do {
                try await GitHubExtrasService.shared.star(owner: item.owner, repo: item.name)
                done += 1
            } catch {
                CrashReporter.log("batch-star: \(item.name) failed")
            }
        }
        batchProgress = nil
        Haptics.success()
        env.show(String(format: NSLocalizedString("已批量星标 %d 个仓库", comment: ""), done), kind: .success)
    }

    private func batchFork() async {
        guard env.pro.hasFullAccess else {
            env.show("批量 Fork 是 Pro 功能（当前限时免费试用中，请先解锁）", kind: .warning)
            return
        }
        guard env.auth.isSignedIn else {
            env.show("请先登录 GitHub", kind: .warning)
            return
        }
        let targets = Array(vault.items.prefix(10))
        guard !targets.isEmpty else { return }

        var done = 0
        for item in targets {
            batchProgress = "\(done)/\(targets.count)"
            do {
                _ = try await GitHubExtrasService.shared.fork(owner: item.owner, repo: item.name)
                done += 1
            } catch {
                CrashReporter.log("batch-fork: \(item.name) failed")
            }
        }
        batchProgress = nil
        Haptics.success()
        env.show(String(format: NSLocalizedString("已 Fork %d 个仓库（上限 10 个/次）", comment: ""), done), kind: .success)
    }

    private func folderRow(_ folder: VaultFolderItem) -> some View {
        Button {
            Haptics.tap()
            openFolder = folder
        } label: {
            folderContent(folder)
        }
        .buttonStyle(.plain)
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

    private func folderContent(_ folder: VaultFolderItem) -> some View {
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

            Text("\(vault.items(inFolder: folder.name).count) 个")
                .font(DS.Typo.caption)
                .foregroundStyle(DS.textTertiary)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DS.textTertiary)
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.bgSecondary)
        )
    }

    private var emptyRow: some View {
        Group {
            if vault.items.isEmpty {
                EmptyStateView(
                    symbol: "bookmark",
                    title: "收藏库还是空的",
                    message: "在发现页看到心动的项目，点一下书签就会出现在这里"
                )
            } else if filtered.isEmpty, groupedCount > 0 {
                EmptyStateView(
                    symbol: "folder",
                    title: "项目都已归入文件夹",
                    message: "上方的文件夹里可以找到它们，长按项目可以移出文件夹"
                )
            } else {
                EmptyStateView(
                    symbol: "bookmark",
                    title: "这个标记下还没有项目",
                    message: "切换标记或去发现页补充几个"
                )
            }
        }
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
                    if item.hasNewRelease == true {
                        HStack(spacing: 3) {
                            Circle().fill(DS.danger).frame(width: 5, height: 5)
                            Text(item.latestReleaseTag ?? "新版本")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(DS.danger)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(DS.danger.opacity(0.12)))
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
