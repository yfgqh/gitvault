//
//  RemoteImage.swift
//  GitVault
//
//  轻量远程图片：内存缓存 + 后台下载 + 淡入。
//  AsyncImage 在滚动列表里会反复解码同一张图，这里用 NSCache 兜住。
//

import SwiftUI

// MARK: - 缓存

final class RemoteImageCache {
    static let shared = RemoteImageCache()

    private let images = NSCache<NSURL, UIImage>()
    private let failed = NSCache<NSURL, NSNumber>()

    private init() {
        images.countLimit = 240
        failed.countLimit = 80
        // 磁盘交给 URLCache（默认 20MB 内存 + 150MB 磁盘）
        URLCache.shared.diskCapacity = 120 * 1024 * 1024
        URLCache.shared.memoryCapacity = 24 * 1024 * 1024
    }

    func cached(_ url: URL) -> UIImage? {
        images.object(forKey: url as NSURL)
    }

    func hasFailed(_ url: URL) -> Bool {
        failed.object(forKey: url as NSURL) != nil
    }

    func load(_ url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        if hasFailed(url) { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 18
            request.setValue("GitVault/\(UpdateChecker.currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let image = UIImage(data: data) else {
                failed.setObject(1, forKey: url as NSURL)
                return nil
            }
            images.setObject(image, forKey: url as NSURL)
            return image
        } catch {
            failed.setObject(1, forKey: url as NSURL)
            return nil
        }
    }
}

// MARK: - 视图

struct RemoteImage<Placeholder: View>: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let hit = RemoteImageCache.shared.cached(url) {
                image = hit
                return
            }
            let loaded = await RemoteImageCache.shared.load(url)
            if let loaded {
                withAnimation(.easeOut(duration: 0.22)) {
                    image = loaded
                }
            }
        }
    }
}

// MARK: - 仓库封面地址

enum RepoImageSource {
    /// GitHub 自动生成的仓库社交卡（1200×630，CDN 缓存，无需 API 请求）
    static func openGraph(owner: String, name: String) -> URL? {
        guard !owner.isEmpty, !name.isEmpty else { return nil }
        return URL(string: "https://opengraph.githubassets.com/1/\(owner)/\(name)")
    }
}
