//
//  OfflineSearchView.swift
//  GitVault
//
//  离线检索：搜本地已缓存的仓库描述与 README，无网也能用。
//

import SwiftUI

struct OfflineSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var index = OfflineIndex.shared

    @State private var keyword = ""
    @State private var results: [OfflineHit] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if index.docs.isEmpty {
                    emptyState
                } else if keyword.trimmingCharacters(in: .whitespaces).isEmpty {
                    hintState
                } else if results.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundStyle(DS.textTertiary)
                        Text("没有匹配的内容")
                            .font(DS.Typo.bodySmall)
                            .foregroundStyle(DS.textSecondary)
                        Text("试试仓库名、语言或 README 里的关键词")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, DS.Space.l)
                } else {
                    ScrollView {
                        LazyVStack(spacing: DS.Space.s) {
                            ForEach(results) { hit in
                                resultRow(hit)
                            }
                        }
                        .padding(.horizontal, DS.Space.screen)
                        .padding(.vertical, DS.Space.m)
                    }
                }
            }
            .background(DS.bgPrimary)
            .navigationTitle("离线搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(index.docs.count) 个已缓存")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textTertiary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
            .onAppear { index.loadIfNeeded() }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(DS.textTertiary)
            TextField("搜仓库名、主题或 README 内容", text: $keyword)
                .font(DS.Typo.bodySmall)
                .foregroundStyle(DS.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: keyword) { value in
                    results = index.search(value)
                }
            if !keyword.isEmpty {
                Button {
                    keyword = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                .fill(DS.bgSecondary)
        )
        .padding(.horizontal, DS.Space.screen)
        .padding(.vertical, DS.Space.s)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 26))
                .foregroundStyle(DS.textTertiary)
            Text("还没有可离线检索的内容")
                .font(DS.Typo.bodySmall)
                .foregroundStyle(DS.textSecondary)
            Text("打开任意仓库详情后，它的描述与 README 会自动存到本地；之后即使没有网络也能搜到。")
                .font(.system(size: 10))
                .foregroundStyle(DS.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Space.l)
        .padding(.top, DS.Space.l)
    }

    private var hintState: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text("最近缓存")
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)
            ForEach(index.docs.prefix(8)) { doc in
                HStack(spacing: 6) {
                    Text(doc.displayName)
                        .font(DS.Typo.bodySmall)
                        .foregroundStyle(DS.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text(doc.language)
                        .font(.system(size: 9))
                        .foregroundStyle(DS.textTertiary)
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Space.l)
        .padding(.top, DS.Space.m)
    }

    private func resultRow(_ hit: OfflineHit) -> some View {
        Button {
            Haptics.tap()
            if let url = URL(string: "https://github.com/\(hit.doc.owner)/\(hit.doc.name)") {
                openURL(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(hit.doc.displayName)
                        .font(DS.Typo.bodySmall)
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(1)
                    TagChip(text: hit.matchedIn, tint: DS.accentAlt, compact: true)
                }
                Text(index.excerpt(for: hit.doc, keyword: keyword))
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textTertiary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(hit.doc.language)
                    Text("★ \(hit.doc.stars)")
                    if !hit.doc.topics.isEmpty {
                        Text(hit.doc.topics.prefix(2).joined(separator: " · "))
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(DS.textTertiary)
            }
            .padding(DS.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(radius: DS.Radius.button)
        }
        .buttonStyle(.springPressCard)
    }
}
