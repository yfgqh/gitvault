//
//  AssetPickerView.swift
//  GitVault
//
//  Release 资产选择器：一个 release 挂了多个平台的包时，让用户自己挑，
//  避免「默认取第一个」下到 Windows 版或 dmg 而用不上。
//

import SwiftUI

struct AssetPickerView: View {
    @ObservedObject var downloader: RepoDownloader
    @Environment(\.dismiss) private var dismiss

    private var grouped: [(kind: String, items: [AssetChoice])] {
        var order: [String] = []
        var map: [String: [AssetChoice]] = [:]
        for asset in downloader.assetChoices {
            if map[asset.kind] == nil { order.append(asset.kind) }
            map[asset.kind, default: []].append(asset)
        }
        return order.map { (kind: $0, items: map[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    header
                    ForEach(grouped, id: \.kind) { group in
                        VStack(alignment: .leading, spacing: DS.Space.s) {
                            Text(group.kind)
                                .font(DS.Typo.caption)
                                .foregroundStyle(DS.textTertiary)

                            ForEach(group.items) { asset in
                                assetRow(asset)
                            }
                        }
                    }

                    sourceRow
                    browserRow
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("选择下载项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        downloader.dismissPicker()
                    }
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.textSecondary)
                }
            }
        }
    }

    /// 次要入口：确实需要看网页时再跳
    private var browserRow: some View {
        Button {
            Haptics.tap()
            downloader.openReleasesInBrowser()
        } label: {
            HStack(spacing: DS.Space.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DS.textTertiary.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "safari")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("在浏览器打开发布页")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.textPrimary)
                    Text("需要登录或查看完整变更说明时使用")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.textSecondary)
            }
            .padding(DS.Space.m)
            .glassSurface(radius: DS.Radius.button)
        }
        .buttonStyle(.springPressSilent)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("这个 Release 提供了 \(downloader.assetChoices.count) 个文件")
                .font(DS.Typo.headline)
                .foregroundStyle(DS.textPrimary)
            Text("按你的设备选择安装包；不确定就直接下源码包自己编译。")
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func assetRow(_ asset: AssetChoice) -> some View {
        Button {
            Haptics.tap()
            downloader.choose(asset)
        } label: {
            HStack(spacing: DS.Space.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint(for: asset.kind).opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: symbol(for: asset.kind))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint(for: asset.kind))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(asset.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if asset.recommended {
                            Text("推荐")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(DS.accentSolid))
                        }
                    }
                    Text("\(asset.kind) · \(asset.sizeText)")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.accent)
            }
            .padding(DS.Space.m)
            .glassSurface(radius: DS.Radius.button)
        }
        .buttonStyle(.springPressSilent)
    }

    private var sourceRow: some View {
        Button {
            Haptics.tap()
            downloader.chooseSourcePackage()
        } label: {
            HStack(spacing: DS.Space.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DS.textTertiary.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("源码包")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.textPrimary)
                    Text("下载仓库当前分支的完整源码（zip）")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.textSecondary)
            }
            .padding(DS.Space.m)
            .glassSurface(radius: DS.Radius.button)
        }
        .buttonStyle(.springPressSilent)
        .padding(.top, DS.Space.s)
    }

    private func symbol(for kind: String) -> String {
        switch kind {
        case "安装包": return "shippingbox.fill"
        case "压缩包": return "doc.zipper"
        default: return "doc"
        }
    }

    private func tint(for kind: String) -> Color {
        switch kind {
        case "安装包": return DS.accent
        case "压缩包": return DS.accentAlt
        default: return DS.textSecondary
        }
    }
}
