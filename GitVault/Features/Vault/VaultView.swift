//
//  VaultView.swift
//  GitVault
//
//  收藏库：统计环形图 + 我的文件夹 + 标记筛选 + 列表。
//  阶段 4 补齐左滑操作（归档 / 在用 / 删除）与拖拽排序。
//

import SwiftUI
import SwiftData

struct VaultView: View {
    @Query(sort: \VaultEntry.savedAt, order: .reverse) private var entries: [VaultEntry]
    @State private var activeMark: MyMark?

    private var filtered: [VaultEntry] {
        guard let activeMark else { return entries }
        return entries.filter { $0.mark == activeMark }
    }

    private func count(_ mark: MyMark) -> Int {
        entries.filter { $0.mark == mark }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    header
                        .screenPadding()
                        .padding(.top, DS.Space.s)

                    statsCard
                        .screenPadding()

                    foldersSection

                    listSection

                    Color.clear.frame(height: DS.Space.tabBarInset)
                }
            }
            .scrollIndicators(.hidden)
            .background(DS.bgPrimary)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

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
            Button {
                Haptics.tap()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(DS.accentGradient))
            }
            .buttonStyle(.springPress)
            .accessibilityLabel("新建文件夹")
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
                        Circle()
                            .fill(mark.tint)
                            .frame(width: 7, height: 7)
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

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            SectionHeader(title: "我的文件夹", subtitle: "阶段 4 支持拖拽排序", actionTitle: nil, onAction: nil)
                .screenPadding()

            VStack(spacing: DS.Space.s) {
                ForEach(MockData.vaultFolders) { folder in
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

                        Text("\(folder.count)")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.textTertiary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DS.textTertiary)
                    }
                    .padding(DS.Space.m)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .fill(DS.bgSecondary)
                    )
                }
            }
            .screenPadding()
        }
    }

    private var listSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            ScrollView(.horizontal) {
                HStack(spacing: DS.Space.s) {
                    FilterChip(title: "全部", isActive: activeMark == nil) {
                        withAnimation(DS.Motion.snappy) { activeMark = nil }
                    }
                    ForEach(MyMark.allCases) { mark in
                        FilterChip(
                            title: mark.title,
                            emoji: mark.emoji,
                            isActive: activeMark == mark
                        ) {
                            withAnimation(DS.Motion.snappy) {
                                activeMark = (activeMark == mark) ? nil : mark
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Space.screen)
            }
            .scrollIndicators(.hidden)

            if filtered.isEmpty {
                EmptyStateView(
                    symbol: "bookmark",
                    title: "收藏库还是空的",
                    message: "在发现页看到心动的项目，点一下书签就会出现在这里",
                    actionTitle: nil,
                    onAction: nil
                )
                .padding(.top, DS.Space.l)
            } else {
                VStack(spacing: DS.Space.s) {
                    ForEach(filtered.indexed) { entry in
                        VaultRow(entry: entry.item)
                            .staggerAppear(entry.index)
                    }
                }
                .screenPadding()
            }
        }
    }
}

/// 收藏行（阶段 4 加 swipeActions）
struct VaultRow: View {
    let entry: VaultEntry

    var body: some View {
        HStack(spacing: DS.Space.m) {
            RepoCover(
                initials: String(entry.owner.prefix(1)).uppercased()
                    + String(entry.name.prefix(1)).uppercased(),
                gradient: entry.category.gradient,
                cornerRadius: 14
            )
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(DS.Typo.headline)
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(1)
                    TagChip(text: entry.mark.title, tint: entry.mark.tint, compact: true)
                }
                Text(entry.summary)
                    .font(DS.Typo.captionRegular)
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Space.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.bgSecondary)
        )
    }
}

#Preview("收藏库") {
    VaultView()
        .modelContainer(for: VaultEntry.self, inMemory: true)
}
