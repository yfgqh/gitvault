//
//  ReadmeFullView.swift
//  GitVault
//
//  README 全文：WKWebView 渲染 HTML，保留标题/列表/表格/图片/视频/链接等原始格式。
//  高度自适应：加载完成后测量 scrollHeight，外层 ScrollView 统一滚动。
//

import SwiftUI
import WebKit

struct HTMLView: UIViewRepresentable {
    let html: String
    @Binding var contentHeight: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.dataDetectorTypes = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.heightBinding = $contentHeight
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedHTML != html else {
            context.coordinator.measure(webView)
            return
        }
        context.coordinator.loadedHTML = html
        context.coordinator.heightBinding = $contentHeight
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedHTML: String?
        var heightBinding: Binding<CGFloat>?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            measure(webView)
        }

        func measure(_ webView: WKWebView) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] value, _ in
                guard let self, let number = value as? NSNumber else { return }
                let height = CGFloat(truncating: number)
                DispatchQueue.main.async {
                    let current = self.heightBinding?.wrappedValue ?? 0
                    if abs(current - height) > 1 {
                        self.heightBinding?.wrappedValue = height
                    }
                }
            }
        }
    }
}

struct ReadmeFullView: View {
    let repo: ShowcaseRepo
    let markdown: String

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var contentHeight: CGFloat = 600

    private var html: String {
        let base = "https://raw.githubusercontent.com/\(repo.owner)/\(repo.name)/HEAD/"
        return MarkdownHTML.render(markdown: markdown,
                                   baseURL: URL(string: base),
                                   isDark: scheme == .dark)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                HTMLView(html: html, contentHeight: $contentHeight)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(contentHeight, 240))
            }
            .background(DS.bgPrimary)
            .navigationTitle("README")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(repo.name)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.textTertiary)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            UIPasteboard.general.string = markdown
                            Haptics.success()
                        } label: {
                            Label("复制 Markdown 原文", systemImage: "doc.on.doc")
                        }
                        if let url = repo.githubURL {
                            Button {
                                openURL(url)
                            } label: {
                                Label("在浏览器打开仓库", systemImage: "safari")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(DS.accent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.accent)
                }
            }
        }
    }
}
