//
//  DetailPresenter.swift
//  GitVault
//
//  详情页改为 overlay 呈现：支持边缘右滑返回，
//  底层页面以 1/3 速度视差跟入，遮罩随进度加深。
//

import SwiftUI

@MainActor
final class DetailPresenter: ObservableObject {
    static let shared = DetailPresenter()

    @Published var stack: [ShowcaseRepo] = []

    var top: ShowcaseRepo? { stack.last }

    var isPresenting: Bool { !stack.isEmpty }

    func open(_ repo: ShowcaseRepo) {
        // 已经在看同一个就不再叠加
        if stack.last?.id == repo.id { return }
        stack.append(repo)
    }

    func close() {
        guard !stack.isEmpty else { return }
        stack.removeLast()
    }

    func closeAll() { stack.removeAll() }
}
