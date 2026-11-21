//
//  DocumentExporter.swift
//  GitVault
//
//  下载完成后让用户选择保存位置（导出到「文件」App 的任意目录）。
//

import SwiftUI
import UniformTypeIdentifiers

struct ExportTarget: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct DocumentExporter: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // asCopy: true 让系统复制一份到用户选择的目录，沙盒里的原文件保留
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.shouldShowFileExtensions = true
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
}
