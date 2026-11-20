//
//  StarQuizView.swift
//  GitVault
//
//  猜星标：两个项目比谁更火。答对连击，记录最高连击。
//

import SwiftUI

struct StarQuizView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var left: ShowcaseRepo?
    @State private var right: ShowcaseRepo?
    @State private var picked: String?
    @State private var streak = 0
    @State private var best = UserDefaults.standard.integer(forKey: "gv.quiz.best")

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Space.l) {
                header

                if let left, let right {
                    HStack(spacing: DS.Space.m) {
                        card(left, isLeft: true)
                        Text("VS")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(DS.textTertiary)
                        card(right, isLeft: false)
                    }
                    .padding(.horizontal, DS.Space.screen)
                } else {
                    ProgressView().tint(DS.accent)
                        .frame(height: 220)
                }

                Spacer(minLength: 0)

                Text("点选你认为 Star 更多的项目")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textTertiary)
                    .padding(.bottom, DS.Space.l)
            }
            .background(DS.bgPrimary)
            .navigationTitle("猜星标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
            .onAppear { next() }
        }
    }

    private var header: some View {
        HStack(spacing: DS.Space.l) {
            VStack(spacing: 2) {
                Text("\(streak)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
                Text("当前连击")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textTertiary)
            }
            VStack(spacing: 2) {
                Text("\(best)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.accent)
                Text("最高连击")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textTertiary)
            }
            Spacer()
            if picked != nil {
                Button {
                    Haptics.tap()
                    next()
                } label: {
                    Text("下一题")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(DS.accentGradient))
                }
                .buttonStyle(.springPressSilent)
            }
        }
        .padding(.horizontal, DS.Space.screen)
        .padding(.top, DS.Space.s)
    }

    private func card(_ repo: ShowcaseRepo, isLeft: Bool) -> some View {
        Button {
            answer(repo)
        } label: {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                AvatarView(url: repo.avatarURL,
                           size: 34,
                           initials: repo.initials,
                           gradient: repo.gradient)

                Text(repo.owner)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.textTertiary)
                    .lineLimit(1)
                Text(repo.name)
                    .font(DS.Typo.body)
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Text(revealText(repo))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(revealedTint(repo))
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .padding(DS.Space.m)
            .glassSurface()
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(borderColor(repo), lineWidth: 1.4)
            )
        }
        .buttonStyle(.springPressSilent)
    }

    private func revealText(_ repo: ShowcaseRepo) -> String {
        guard picked != nil else { return "？" }
        return repo.starText
    }

    private func revealedTint(_ repo: ShowcaseRepo) -> Color {
        guard picked != nil else { return DS.textTertiary }
        return repo.id == winner?.id ? DS.success : DS.danger
    }

    private func borderColor(_ repo: ShowcaseRepo) -> Color {
        guard let picked else { return Color.clear }
        if repo.id == picked {
            return repo.id == winner?.id ? DS.success.opacity(0.7) : DS.danger.opacity(0.6)
        }
        return Color.clear
    }

    private var winner: ShowcaseRepo? {
        guard let left, let right else { return nil }
        return left.stars >= right.stars ? left : right
    }

    // MARK: 逻辑

    private func answer(_ repo: ShowcaseRepo) {
        guard picked == nil else { return }
        picked = repo.id
        if repo.id == winner?.id {
            streak += 1
            Haptics.success()
            if streak > best {
                best = streak
                UserDefaults.standard.set(best, forKey: "gv.quiz.best")
            }
            env.show("答对了 · 连击 \(streak)", kind: .success)
        } else {
            streak = 0
            Haptics.warning()
            env.show("差一点，看看真实 Star 数", kind: .warning)
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run { next() }
        }
    }

    private func next() {
        var pool = env.allRepos.repos
        if pool.count < 6 { pool = MockData.repos }
        guard pool.count >= 2 else { return }

        var a = pool.randomElement()
        var b = pool.randomElement()
        var guardCount = 0
        while (b?.id == a?.id || abs((a?.stars ?? 0) - (b?.stars ?? 0)) < 200), guardCount < 20 {
            a = pool.randomElement()
            b = pool.randomElement()
            guardCount += 1
        }
        left = a
        right = b
        picked = nil
    }
}
