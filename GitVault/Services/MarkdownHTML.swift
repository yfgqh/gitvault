//
//  MarkdownHTML.swift
//  GitVault
//
//  轻量 Markdown → HTML：用于在 WKWebView 里按原文格式展示 README。
//  覆盖：标题 / 段落 / 粗斜体 / 行内代码 / 代码块 / 列表 / 引用 / 表格 /
//        分割线 / 链接 / 图片 / 视频 / 原始 HTML 块（净化 script）。
//

import Foundation

enum MarkdownHTML {

    // MARK: 入口

    static func render(markdown: String, baseURL: URL?, isDark: Bool) -> String {
        let body = convert(markdown)
        let base = baseURL?.absoluteString ?? "https://github.com"
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <base href="\(escapeAttribute(base))/">
        <style>\(style(isDark: isDark))</style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    // MARK: 主转换

    private static func convert(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var html: [String] = []
        var index = 0

        while index < lines.count {
            let raw = lines[index]
            let line = raw.trimmingCharacters(in: .whitespaces)

            // 代码块
            if line.hasPrefix("```") {
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var buffer: [String] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    buffer.append(lines[index])
                    index += 1
                }
                index += 1 // 跳过结尾 ```
                html.append("<pre><code class=\"lang-\(escapeAttribute(language))\">\(escape(buffer.joined(separator: "\n")))</code></pre>")
                continue
            }

            // 原始 HTML 块（div/details/img/video/table 等）
            if line.hasPrefix("<") {
                var buffer: [String] = []
                while index < lines.count {
                    let current = lines[index]
                    buffer.append(current)
                    index += 1
                    if current.trimmingCharacters(in: .whitespaces).hasSuffix(">"),
                       !current.contains("<details"), !current.contains("<div"), !current.contains("<table") {
                        break
                    }
                    if current.trimmingCharacters(in: .whitespaces).hasSuffix("</details>")
                        || current.trimmingCharacters(in: .whitespaces).hasSuffix("</div>")
                        || current.trimmingCharacters(in: .whitespaces).hasSuffix("</table>") {
                        break
                    }
                }
                let block = buffer.joined(separator: "\n")
                html.append(sanitizeHTML(block))
                continue
            }

            // 标题
            if line.hasPrefix("#") {
                var level = 0
                for character in line {
                    if character == "#" { level += 1 } else { break }
                }
                if level >= 1, level <= 6 {
                    let text = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    html.append("<h\(level)>\(inline(text))</h\(level)>")
                    index += 1
                    continue
                }
            }

            // 分割线
            if line == "---" || line == "***" || line == "___" {
                html.append("<hr>")
                index += 1
                continue
            }

            // 表格
            if line.hasPrefix("|"), line.hasSuffix("|") {
                var rows: [[String]] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard current.hasPrefix("|"), current.hasSuffix("|") else { break }
                    rows.append(current.dropFirst().dropLast()
                        .split(separator: "|", omittingEmptySubsequences: false)
                        .map { $0.trimmingCharacters(in: .whitespaces) })
                    index += 1
                }
                html.append(tableHTML(rows))
                continue
            }

            // 引用
            if line.hasPrefix(">") {
                var buffer: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard current.hasPrefix(">") else { break }
                    buffer.append(String(current.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                html.append("<blockquote>\(inline(buffer.joined(separator: "<br>")))</blockquote>")
                continue
            }

            // 无序列表
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                var items: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard current.hasPrefix("- ") || current.hasPrefix("* ") || current.hasPrefix("+ ") else { break }
                    items.append(String(current.dropFirst(2)))
                    index += 1
                }
                html.append("<ul>" + items.map { "<li>\(inline($0))</li>" }.joined() + "</ul>")
                continue
            }

            // 有序列表
            if let _ = line.range(of: "^\\d+\\.\\s", options: .regularExpression) {
                var items: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard current.range(of: "^\\d+\\.\\s", options: .regularExpression) != nil else { break }
                    let text = current.replacingOccurrences(of: "^\\d+\\.\\s", with: "", options: .regularExpression)
                    items.append(text)
                    index += 1
                }
                html.append("<ol>" + items.map { "<li>\(inline($0))</li>" }.joined() + "</ol>")
                continue
            }

            // 空行
            if line.isEmpty {
                index += 1
                continue
            }

            // 段落（合并连续非空行）
            var paragraph: [String] = [line]
            index += 1
            while index < lines.count {
                let current = lines[index].trimmingCharacters(in: .whitespaces)
                if current.isEmpty || current.hasPrefix("#") || current.hasPrefix("```")
                    || current.hasPrefix("|") || current.hasPrefix(">")
                    || current.hasPrefix("- ") || current.hasPrefix("* ")
                    || current.hasPrefix("<") || current == "---" {
                    break
                }
                paragraph.append(current)
                index += 1
            }
            html.append("<p>\(inline(paragraph.joined(separator: "<br>")))</p>")
        }

        return html.joined(separator: "\n")
    }

    // MARK: 行内

    private static func inline(_ text: String) -> String {
        var output = escape(text)

        // 行内代码先抽出，避免内部内容被进一步解析
        var codes: [String] = []
        output = replaceAll(output, pattern: "`([^`]+)`") { groups in
            codes.append(groups[0])
            return "\u{0001}\(codes.count - 1)\u{0001}"
        }

        // 图片
        output = replaceAll(output, pattern: "!\\[([^\\]]*)\\]\\((https?://[^)\\s]+)\\)") { groups in
            let alt = groups[0]
            let src = groups[1]
            if isVideo(src) {
                return "<video src=\"\(src)\" controls playsinline preload=\"metadata\"></video>"
            }
            return "<img src=\"\(src)\" alt=\"\(alt)\" loading=\"lazy\">"
        }

        // 链接
        output = replaceAll(output, pattern: "\\[([^\\]]+)\\]\\((https?://[^)\\s]+)\\)") { groups in
            "<a href=\"\(groups[1])\">\(groups[0])</a>"
        }

        // 相对链接（/path 或 ./path）补成 github 绝对地址
        output = replaceAll(output, pattern: "\\[([^\\]]+)\\]\\((/[^)\\s]+)\\)") { groups in
            "<a href=\"https://github.com\(groups[1])\">\(groups[0])</a>"
        }

        // 裸 URL
        output = replaceAll(output, pattern: "(?<![\"'>])(https?://[^\\s<]+)") { groups in
            "<a href=\"\(groups[0])\">\(groups[0])</a>"
        }

        // 粗斜体
        output = replaceAll(output, pattern: "\\*\\*\\*([^*]+)\\*\\*\\*") { g in "<strong><em>\(g[0])</em></strong>" }
        output = replaceAll(output, pattern: "\\*\\*([^*]+)\\*\\*") { g in "<strong>\(g[0])</strong>" }
        output = replaceAll(output, pattern: "__([^_]+)__") { g in "<strong>\(g[0])</strong>" }
        output = replaceAll(output, pattern: "\\*([^*]+)\\*") { g in "<em>\(g[0])</em>" }
        output = replaceAll(output, pattern: "~~([^~]+)~~") { g in "<del>\(g[0])</del>" }

        // 回填行内代码
        for (offset, code) in codes.enumerated() {
            output = output.replacingOccurrences(of: "\u{0001}\(offset)\u{0001}", with: "<code>\(escape(code))</code>")
        }
        return output
    }

    // MARK: 表格

    private static func tableHTML(_ rows: [[String]]) -> String {
        guard !rows.isEmpty else { return "" }
        var result = "<table>"
        for (index, row) in rows.enumerated() {
            // 第二行是分隔符 |---|---|
            if index == 1, row.allSatisfy({ $0.allSatisfy { $0 == "-" || $0 == ":" } }) {
                continue
            }
            let tag = index == 0 ? "th" : "td"
            result += "<tr>" + row.map { "<\(tag)>\(inline($0))</\(tag)>" }.joined() + "</tr>"
        }
        result += "</table>"
        return result
    }

    // MARK: 工具

    private static func isVideo(_ url: String) -> Bool {
        let lower = url.lowercased()
        return [".mp4", ".webm", ".mov", ".m4v"].contains { lower.hasSuffix($0) || lower.contains($0 + "?") }
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func escapeAttribute(_ text: String) -> String { escape(text) }

    /// 去掉脚本类标签，其余保留
    private static func sanitizeHTML(_ block: String) -> String {
        var cleaned = block
        for pattern in ["<script[^>]*>.*?</script>", "<iframe[^>]*>.*?</iframe>",
                        "<style[^>]*>.*?</style>", "on\\w+=\"[^\"]*\""] {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return cleaned
    }

    /// 统一的替换实现：groups 为空时传入 [完整匹配]
    private static func replaceAll(_ text: String,
                                   pattern: String,
                                   _ transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var result = text

        // 倒序替换：后面的替换不会影响前面 match 的索引
        for match in regex.matches(in: text, options: [], range: nsRange).reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let sourceRange = Range(match.range, in: text) else { continue }

            let full = String(text[sourceRange])
            var groups: [String] = []
            for index in 1..<match.numberOfRanges {
                if let groupRange = Range(match.range(at: index), in: text) {
                    groups.append(String(text[groupRange]))
                } else {
                    groups.append("")
                }
            }
            result.replaceSubrange(fullRange, with: transform(groups.isEmpty ? [full] : groups))
        }
        return result
    }
    // MARK: 样式

    private static func style(isDark: Bool) -> String {
        let background = isDark ? "#0B0E14" : "#FFFFFF"
        let text = isDark ? "#E6E9F0" : "#1B1F27"
        let secondary = isDark ? "#9AA3B2" : "#5A6472"
        let accent = "#7C6DF2"
        let codeBackground = isDark ? "#171B24" : "#F3F4F8"
        let border = isDark ? "#252A36" : "#E3E6ED"

        return """
        :root { color-scheme: \(isDark ? "dark" : "light"); }
        * { box-sizing: border-box; }
        body {
          margin: 0; padding: 16px;
          background: \(background); color: \(text);
          font: -apple-system-body;
          font-family: -apple-system, "SF Pro Text", "PingFang SC", system-ui, sans-serif;
          font-size: 15px; line-height: 1.68;
          -webkit-text-size-adjust: 100%;
          word-wrap: break-word;
        }
        h1, h2, h3, h4, h5, h6 { line-height: 1.3; margin: 22px 0 10px; font-weight: 700; }
        h1 { font-size: 24px; border-bottom: 1px solid \(border); padding-bottom: 8px; }
        h2 { font-size: 20px; border-bottom: 1px solid \(border); padding-bottom: 6px; }
        h3 { font-size: 17px; }
        h4, h5, h6 { font-size: 15px; }
        p { margin: 10px 0; }
        a { color: \(accent); text-decoration: none; }
        img { max-width: 100%; height: auto; border-radius: 10px; display: block; margin: 12px 0; }
        video { max-width: 100%; border-radius: 10px; margin: 12px 0; }
        code {
          font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
          font-size: 13px; background: \(codeBackground);
          padding: 2px 5px; border-radius: 5px;
        }
        pre {
          background: \(codeBackground); padding: 12px; border-radius: 10px;
          overflow-x: auto; margin: 12px 0;
        }
        pre code { background: transparent; padding: 0; font-size: 12.5px; line-height: 1.55; }
        blockquote {
          margin: 12px 0; padding: 8px 12px;
          border-left: 3px solid \(accent); color: \(secondary);
          background: \(codeBackground); border-radius: 0 8px 8px 0;
        }
        ul, ol { margin: 10px 0; padding-left: 22px; }
        li { margin: 4px 0; }
        hr { border: none; border-top: 1px solid \(border); margin: 18px 0; }
        table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 13px; display: block; overflow-x: auto; }
        th, td { border: 1px solid \(border); padding: 6px 10px; text-align: left; }
        th { background: \(codeBackground); font-weight: 600; }
        details { margin: 10px 0; }
        summary { color: \(accent); }
        """
    }
}
