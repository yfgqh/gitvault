import SwiftUI
import UIKit

/// 系统分享面板（导出 JSON / Markdown 用）
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// 可分享的文件包装（Identifiable，便于 sheet(item:)）
struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}
