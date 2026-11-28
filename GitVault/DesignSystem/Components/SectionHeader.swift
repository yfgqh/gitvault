//
//  SectionHeader.swift
//  GitVault
//
//  区块标题：左标题 + 副标题，右侧可选「查看全部」。
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = "查看全部"
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typo.title)
                    .foregroundStyle(DS.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typo.captionRegular)
                        .foregroundStyle(DS.textTertiary)
                }
            }

            Spacer(minLength: DS.Space.s)

            if let actionTitle, let onAction {
                Button {
                    Haptics.tap()
                    onAction()
                } label: {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                            .font(DS.Typo.caption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(DS.accent)
                }
                .buttonStyle(.springPressSilent)
            }
        }
    }
}

#Preview("区块标题") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        SectionHeader(title: "飙升榜", subtitle: "近 24 小时 star 增速", onAction: {})
            .padding()
    }
}
