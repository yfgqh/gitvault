//
//  ShareVaultHTML.swift
//  GitVault
//
//  分享收藏夹：把选中的收藏（或整个文件夹）导出为一个可独立打开的 HTML 页面。
//  生成的页面无外部依赖，直接拖进浏览器即可看，也可以丢到 GitHub Pages。
//

import Foundation
import SwiftUI

enum ShareVaultHTML {

    static func build(items: [VaultItem], title: String, isDark: Bool = true) -> String {
        let grouped = Dictionary(grouping: items, by: { $0.category })
        var sections = ""

        for category in RepoCategory.allCases {
            guard let list = grouped[category], !list.isEmpty else { continue }
            let cards = list
                .sorted { $0.stars > $1.stars }
                .map { card($0) }
                .joined(separator: "\n")
            sections += """
            <section>
              <h2>\(category.emoji) \(escape(category.title)) <span class="count">\(list.count)</span></h2>
              <div class="grid">\(cards)</div>
            </section>
            """
        }

        let background = isDark ? "#0B0E14" : "#FFFFFF"
        let text = isDark ? "#E6E9F0" : "#1B1F27"
        let sub = isDark ? "#9AA3B2" : "#5A6472"
        let cardBG = isDark ? "#151A23" : "#F5F6FA"
        let border = isDark ? "#242A36" : "#E3E6ED"

        let generated = DateFormatter.localizedString(from: .now, dateStyle: .medium, timeStyle: .short)

        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title>
        <style>
        * { box-sizing: border-box; }
        body { margin: 0; padding: 32px 20px 64px; background: \(background); color: \(text);
               font-family: -apple-system, "PingFang SC", system-ui, sans-serif; line-height: 1.6; }
        h1 { font-size: 28px; margin: 0 0 6px; }
        .meta { color: \(sub); font-size: 13px; margin-bottom: 28px; }
        h2 { font-size: 18px; margin: 32px 0 12px; }
        .count { color: \(sub); font-weight: 400; font-size: 13px; margin-left: 6px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px; }
        .card { background: \(cardBG); border: 1px solid \(border); border-radius: 14px; padding: 14px; }
        .card h3 { margin: 0 0 4px; font-size: 15px; }
        .card h3 a { color: \(text); text-decoration: none; }
        .card .owner { color: \(sub); font-size: 11px; margin-bottom: 8px; }
        .card p { margin: 0 0 10px; font-size: 13px; color: \(sub); }
        .card .note { font-size: 12px; color: \(text); background: rgba(124,109,242,.12);
                      border-left: 2px solid #7C6DF2; padding: 6px 8px; border-radius: 0 6px 6px 0; margin-bottom: 10px; }
        .card .row { display: flex; gap: 12px; font-size: 11px; color: \(sub); flex-wrap: wrap; }
        footer { margin-top: 48px; color: \(sub); font-size: 12px; text-align: center; }
        </style>
        </head>
        <body>
        <h1>\(escape(title))</h1>
        <div class="meta">共 \(items.count) 个项目 · 导出于 \(escape(generated)) · 由 GitVault 生成</div>
        \(sections.isEmpty ? "<p>这个收藏夹还是空的。</p>" : sections)
        <footer>GitVault · GitHub 精选</footer>
        </body>
        </html>
        """
    }

    private static func card(_ item: VaultItem) -> String {
        let url = item.htmlURL.isEmpty ? "https://github.com/\(item.owner)/\(item.name)" : item.htmlURL
        let note = item.note.map { "<div class=\"note\">\(escape($0))</div>" } ?? ""
        return """
        <article class="card">
          <h3><a href="\(escape(url))" target="_blank" rel="noopener">\(escape(item.name))</a></h3>
          <div class="owner">\(escape(item.owner))</div>
          <p>\(escape(item.summary))</p>
          \(note)
          <div class="row">
            <span>★ \(compact(item.stars))</span>
            <span>⑂ \(compact(item.forks))</span>
            <span>\(escape(item.language))</span>
            <span>\(escape(item.license.title))</span>
          </div>
        </article>
        """
    }

    static func writeFile(items: [VaultItem], title: String) -> URL? {
        let html = build(items: items, title: title)
        let dir = FileManager.default.temporaryDirectory
        let safeTitle = title.replacingOccurrences(of: "/", with: "-")
        let url = dir.appendingPathComponent("GitVault-\(safeTitle)-\(Int(Date().timeIntervalSince1970)).html")
        do {
            try html.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            CrashReporter.log("share-html: write failed \(error.localizedDescription)")
            return nil
        }
    }

    private static func compact(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000)
        }
        return "\(value)"
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
