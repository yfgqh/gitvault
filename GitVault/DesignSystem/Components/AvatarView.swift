//
//  AvatarView.swift
//  GitVault
//
//  头像加载：自建内存缓存 + URLSession，不用 AsyncImage。
//  AsyncImage 每次 body 重算都会回到 empty 态并重建任务，
//  列表滚动时表现为「头像一闪一闪」——这是本次闪烁问题的第二个来源。
//

import SwiftUI
import UIKit

/// 进程内图片缓存（NSCache 自动响应内存警告）
final class ImageMemoryCache {
    static let shared = ImageMemoryCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 300
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

@MainActor
final class RemoteImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = false

    private var currentURL: URL?
    private var task: URLSessionDataTask?

    func load(_ url: URL?) {
        guard let url else {
            currentURL = nil
            image = nil
            isLoading = false
            return
        }
        if currentURL == url { return }

        currentURL = url
        if let cached = ImageMemoryCache.shared.image(for: url) {
            image = cached
            isLoading = false
            return
        }

        image = nil
        isLoading = true
        task?.cancel()
        task = URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let decoded = UIImage(data: data) else {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.currentURL == url else { return }
                    self.isLoading = false
                }
                return
            }
            ImageMemoryCache.shared.store(decoded, for: url)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.currentURL == url else { return }
                self.image = decoded
                self.isLoading = false
            }
        }
        task?.resume()
    }

    deinit {
        task?.cancel()
    }
}

struct AvatarView: View {
    let url: URL?
    var size: CGFloat = 36
    var initials: String = "G"
    var gradient: [Color] = [DS.accent, DS.accentAlt]

    @StateObject private var loader = RemoteImageLoader()

    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .onAppear { loader.load(url) }
        .onChange(of: url) { newValue in loader.load(newValue) }
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(initials)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

#Preview("头像") {
    ZStack {
        DS.bgPrimary.ignoresSafeArea()
        HStack(spacing: 16) {
            AvatarView(url: nil, size: 56, initials: "LL")
            AvatarView(url: URL(string: "https://avatars.githubusercontent.com/u/1?v=4"), size: 56)
        }
    }
}
