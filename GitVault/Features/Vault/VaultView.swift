//
//  VaultView.swift
//  GitVault
//
//  收藏库：环形统计 + 自定义文件夹 + 标记筛选 + 左滑操作 + 拖拽排序 + 导出。
//  数据源：SwiftData（VaultEntry / VaultFolder），写操作统一走 VaultService。
//

import SwiftUI
import SwiftData

struct VaultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEnvironment.self) private var env

    @Query(sort: [SortDescriptor(\VaultEntry.sortIndex, order: .forward)])
    private var entries: [VaultEntry]
    @Query(sort: [SortDescriptor(\VaultFolder.sortIndex, order: .forward)])
    private var folders: [VaultFolder]

    @State private var activeMark: MyMark?
    @State private var editMode: EditMode = .inactive
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var exportFile: ExportFile?
    @State private var moveTarget: VaultEntry?

    private var service: VaultService { VaultService(context: modelContext) }

    private var filtered: [VaultEntry] {
        guard let activeMark else { return entries }
        return entries.filter { $0.mark == activeMark }
    }

    private func count(_ mark: MyMark) -> Int {
        entries.filter { $0.mark == mark }.count
    }

    private func folderEntries(_ folder: VaultFolder) -> [VaultEntry] {
        entries.filter { $0.folderName == folder.name }
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
            .toolbar(.hidden, for: .navigationBar)
            .alert("新建文件夹", isPresented: $showingNewFolder) {
                TextField("文件夹名称", text: $newFolderName)
                Button("取消", role: .cancel) { newFolderName = "" }
                Button("创建") {
                    if let folder = service.createFolder(name: newFolderName) {
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
                ForEach(folders) { folder in
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
                    .init(value: count(.starred), color: MyMark.starred.tint, label: "收藏"),
                    .init(value: count(.inUse), color: MyMark.inUse.tint, label: "在用"),
                    .init(value: count(.watching), color: MyMark.watching.tint, label: "观察"),
                    .init(value: count(.archived), color: MyMark.archived.tint, label: "归档")
                ],
                total: entries.count
            )

            VStack(alignment: .leading, spacing: DS.Space.s) {
                ForEach(MyMark.allCases) { mark in
                    HStack(spacing: 8) {
                        Circle().fill(mark.tint).frame(width: 7, height: 7)
                        Text(mark.emoji + " " + mark.title)
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textSecondary)
                        Spacer(minLength: 4)
                        Text("\(count(mark))")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textPrimary)
                            .contentTransition(.numericText())
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
            if !folders.isEmpty {
                Section {
                    ForEach(folders) { folder in
                        folderRow(folder)
                    }
                } header: {
                    sectionHeader("我的文件夹", detail: "\(folders.count) 个")
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
            ForEach(filtered) { entry in
                entryRow(entry)
            }
            .onMove { from, to in
                var ordered = filtered
                ordered.move(fromOffsets: from, toOffset: to)
                service.persistOrder(ordered)
                Haptics.tap()
            }
        } else {
            ForEach(filtered) { entry in
                entryRow(entry)
            }
        }
    }

    private func entryRow(_ entry: VaultEntry) -> some View {
        VaultRow(entry: entry)
            .listRowInsets(EdgeInsets(top: 4, leading: DS.Space.screen, bottom: 4, trailing: DS.Space.screen))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    service.remove(entry)
                    Haptics.warning()
                    env.show("已删除：\(entry.name)", kind: .info)
                } label: {
                    Label("删除", systemImage: "trash")
                }

                Button {
                    service.setMark(entry, to: .archived)
                    Haptics.tap()
                } label: {
                    Label("归档", systemImage: "archivebox")
                }
                .tint(.orange)

                Button {
                    service.setMark(entry, to: .inUse)
                    Haptics.success()
                } label: {
                    Label("在用", systemImage: "hammer")
                }
                .tint(DS.accent)
            }
            .swipeActions(edge: .leading) {
                Button {
                    service.setMark(entry, to: .watching)
                    Haptics.tap()
                } label: {
                    Label("观察", systemImage: "eye")
                }
                .tint(Color(hex: 0x6EE7FF))

                Button {
                    moveTarget = entry
                } label: {
                    Label("分组", systemImage: "folder")
                }
                .tint(Color(hex: 0xA66CFF))
            }
            .contextMenu {
                ForEach(MyMark.allCases) { mark in
                    Button {
                        service.setMark(entry, to: mark)
                        Haptics.tap()
                    } label: {
                        Label("标为\(mark.title)", systemImage: mark.symbol)
                    }
                }
                Button {
                    moveTarget = entry
                } label: {
                    Label("移入文件夹", systemImage: "folder")
                }
            }
    }

    private func folderRow(_ folder: VaultFolder) -> some View {
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

            Text("\(folderEntries(folder).count)")
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
                service.deleteFolder(folder)
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

    private func move(_ entry: VaultEntry?, to folder: String?) {
        guard let entry else { return }
        service.assign(entry, to: folder)
        moveTarget = nil
        Haptics.success()
        env.show(folder.map { "已移入 \($0)" } ?? "已取消分组", kind: .success)
    }

    private func export(_ format: VaultService.ExportFormat) {
        do {
            let url = try service.export(format)
            exportFile = ExportFile(url: url, title: "导出 \(format.rawValue.uppercased())")
            Haptics.success()
        } catch {
            env.show("导出失败：\(error.localizedDescription)", kind: .warning)
        }
    }
}

/// 收藏行
struct VaultRow: View {
    let entry: VaultEntry

    var body: some View {
        HStack(spacing: DS.Space.m) {
            AvatarView(
                url: entry.avatarURL.flatMap(URL.init(string:)),
                size: 46,
                initials: String(entry.owner.prefix(1)).uppercased()
                    + String(entry.name.prefix(1)).uppercased(),
                gradient: entry.category.gradient
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(DS.Typo.headline)
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(1)
                    TagChip(text: entry.mark.title, tint: entry.mark.tint, compact: true)
                    if let folder = entry.folderName {
                        TagChip(text: folder, systemImage: "folder", tint: DS.textTertiary, compact: true)
                    }
                }
                Text(entry.summary)
                    .font(DS.Typo.captionRegular)
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("★ \(ShowcaseRepo.compact(entry.stars))")
                    .font(DS.Typo.micro)
                    .foregroundStyle(DS.textTertiary)
                Text(entry.category.emoji)
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
        .environment(AppEnvironment())
        .modelContainer(for: [VaultEntry.self, VaultFolder.self], inMemory: true)
}
