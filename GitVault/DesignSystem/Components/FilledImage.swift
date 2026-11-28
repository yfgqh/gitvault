//
//  RemoteImage.swift
//  GitVault
//
//  统一入口：所有远程图片都走这里，保证「图片适应容器」而不是撑大容器。
//

import SwiftUI

// MARK: - 缓存

final class RemoteImageCache {
    static let shared = RemoteImageCache()

    private let images = NSCache<NSURL, UIImage>()
    private let failed = NSCache<NSURL, NSNumber>()

    private init() {
        images.countLimit = 260
        failed.countLimit = 120
        URLCache.shared.diskCapacity = 150 * 1024 * 1024
        URLCache.shared.memoryCapacity = 32 * 1024 * 1024
    }

    func cached(_ url: URL) -> UIImage? { images.object(forKey: url as NSURL) }
    func hasFailed(_ url: URL) -> Bool { failed.object(forKey: url as NSURL) != nil }

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

/// 填满给定尺寸、绝不溢出的远程图片。
/// 关键：用 GeometryReader 给子视图**明确的宽高**，而不是只在外层加 frame ——
/// 后者不会约束 `scaledToFill` 的图片，图片会按原图比例撑出容器。
struct FilledRemoteImage<Placeholder: View>: View {
    let url: URL?
    var cornerRadius: CGFloat = 0
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    placeholder()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: url) {
            guard let url else { return }
            if let hit = RemoteImageCache.shared.cached(url) {
                image = hit
                return
            }
            let loaded = await RemoteImageCache.shared.load(url)
            if let loaded {
                withAnimation(.easeOut(duration: 0.22)) { image = loaded }
            }
        }
    }
}
