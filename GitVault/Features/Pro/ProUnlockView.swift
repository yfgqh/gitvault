//
//  ProUnlockView.swift
//  GitVault
//
//  Pro 解锁页：¥9.9 一次性买断，唯一档位。
//

import SwiftUI

struct ProUnlockView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    private var pro: ProStore { env.pro }

    private let benefits: [(String, String, String)] = [
        ("infinity", "AI 翻译无限", "免费版每日 20 次；Pro 不限次数，长文自动分节翻译"),
        ("arrow.down.circle", "离线全量库", "把 star>500 的仓库全部缓存到本地，地铁与弱网也能搜索浏览"),
        ("square.stack.3d.up", "批量操作", "批量星标、批量 Fork、批量导出，整理上百条收藏不用逐条点"),
        ("bell.badge", "更新提醒", "收藏的仓库发布新版本时在列表里标出来，不错过重要变更"),
        ("chevron.left.forwardslash.chevron.right", "代码浏览增强", "文件内搜索与关键字高亮，读源码更省力")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    hero
                    benefitList
                    purchaseSection
                    footnote
                }
                .padding(DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("GitVault Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
            .task {
                if pro.product == nil { await pro.bootstrap() }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: DS.Space.m) {
                GBLogoMark(size: 56, glow: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text("解锁 Pro")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.textPrimary)
                    Text(pro.statusTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(pro.isPro ? DS.success : DS.accent)
                }
                Spacer(minLength: 0)
            }

            Text("当前限时免费：Pro 全部功能试用 365 天，无需付费。")
                .font(DS.Typo.bodySmall)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.m)
        .glassSurface()
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            ForEach(benefits.indices, id: \.self) { index in
                let item = benefits[index]
                HStack(alignment: .top, spacing: DS.Space.m) {
                    Image(systemName: item.0)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.accent)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(DS.accent.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.1)
                            .font(DS.Typo.body)
                            .foregroundStyle(DS.textPrimary)
                        Text(item.2)
                            .font(.system(size: 11))
                            .foregroundStyle(DS.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: DS.Space.s) {
            if pro.isPro {
                Label("Pro 已解锁，感谢支持", systemImage: "checkmark.seal.fill")
                    .font(DS.Typo.body)
                    .foregroundStyle(DS.success)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                            .fill(DS.success.opacity(0.12))
                    )
            } else {
                Button {
                    Task { await pro.purchase() }
                } label: {
                    HStack(spacing: 6) {
                        if pro.isLoading { ProgressView().scaleEffect(0.7).tint(.white) }
                        Text("解锁 Pro · 当前限时免费")
                            .font(DS.Typo.body)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                            .fill(DS.accentSolid)
                    )
                }
                .buttonStyle(.springPress)
                .disabled(pro.isLoading)
            }

            Button {
                Task { await pro.restore() }
            } label: {
                Text("恢复购买")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                            .fill(DS.bgSecondary)
                    )
            }
            .buttonStyle(.springPressSilent)

            if let message = pro.message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var footnote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("免费版永久可用：浏览、搜索、分类、无限收藏、README 原文都能正常使用。Pro 只增加「省时间」和「更体面」的增量能力。")
                .font(.system(size: 11))
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

        }
    }
}
