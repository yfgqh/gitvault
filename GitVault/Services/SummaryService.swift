//
//  SummaryService.swift
//  GitVault
//
//  中文摘要：优先用仓库自带的 description（若已是中文），否则用规则模板拼一句中文，
//  并把 GitHub 英文 topics 映射成中文词。阶段 5 的 LLM 实现可直接替换本服务。
//

import Foundation

enum SummaryService {

    /// 常见英文 topic → 中文词，用于把一句话说人话
    static let topicZh: [String: String] = [
        "llm": "大语言模型", "agent": "智能体", "agents": "智能体",
        "rag": "检索增强", "embedding": "向量检索", "diffusion": "扩散模型",
        "transformer": "Transformer", "inference": "推理加速", "finetune": "微调",
        "cv": "计算机视觉", "nlp": "自然语言处理", "multimodal": "多模态",
        "cli": "命令行工具", "terminal": "终端", "vscode": "VS Code 插件",
        "plugin": "插件", "build": "构建工具", "bundler": "打包器", "linter": "代码检查",
        "devops": "DevOps", "kubernetes": "K8s", "docker": "容器", "ci": "持续集成",
        "react": "React", "vue": "Vue", "svelte": "Svelte", "nextjs": "Next.js",
        "css": "样式", "tailwind": "原子化 CSS", "component": "组件库", "components": "组件库",
        "ui": "界面组件", "design-system": "设计系统", "animation": "动效",
        "database": "数据库", "redis": "缓存", "kafka": "消息队列", "grpc": "RPC",
        "microservice": "微服务", "distributed": "分布式", "server": "服务端",
        "ios": "iOS", "swiftui": "SwiftUI", "android": "Android", "kotlin": "Kotlin",
        "flutter": "Flutter", "react-native": "React Native", "harmony": "鸿蒙",
        "awesome": "Awesome 清单", "tutorial": "教程", "roadmap": "学习路线",
        "interview": "面试", "algorithm": "算法", "book": "电子书", "course": "课程",
        "template": "模板", "starter": "脚手架", "sdk": "SDK", "library": "库",
        "framework": "框架", "tool": "工具", "tools": "工具集", "web": "Web",
        "api": "API", "client": "客户端", "machine-learning": "机器学习", "data": "数据"
    ]

    /// 一句话中文摘要
    static func chineseSummary(for dto: RepositoryDTO, category: RepoCategory) -> String {
        let description = (dto.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) 原描述已是中文：直接当摘要（截断到一句话）
        if containsCJK(description) {
            return firstSentence(description)
        }

        // 2) 规则模板：语言 + 主题 + 中文 topic 词
        let language = dto.language ?? "多语言"
        let topicPhrase = chineseTopics(dto.topics ?? [], limit: 3)
        var sentence = "一个用 \(language) 编写的\(category.title)项目"
        if !topicPhrase.isEmpty {
            sentence += "，重点在\(topicPhrase)"
        }
        sentence += "。"

        // 3) 英文原始描述作为补充，帮助用户判断
        if !description.isEmpty {
            sentence += "原描述：\(firstSentence(description))"
        }
        return sentence
    }

    /// 把英文 topics 翻成中文短语
    static func chineseTopics(_ topics: [String], limit: Int = 3) -> String {
        let mapped = topics.compactMap { topic -> String? in
            let key = topic.lowercased()
            if let zh = topicZh[key] { return zh }
            // 含连字符的复合 topic：逐段翻译
            if key.contains("-") {
                let parts = key.split(separator: "-").compactMap { topicZh[String($0)] }
                if !parts.isEmpty { return parts.joined() }
            }
            return nil
        }
        let unique = Array(NSOrderedSet(array: mapped)) as? [String] ?? mapped
        return unique.prefix(limit).joined(separator: "、")
    }

    /// README 摘要素材：抽取标题结构 + 首段文字（本地规则，不联网翻译）
    static func summarizeReadme(_ markdown: String, headingLimit: Int = 6) -> String {
        let lines = markdown.components(separatedBy: .newlines)

        // 1) 二级标题当目录
        var headings: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { continue }
            let text = trimmed.replacingOccurrences(of: "#", with: "")
                .trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, !text.lowercased().contains("badge") else { continue }
            if containsCJK(text) || text.count <= 24 {
                headings.append(text)
            }
            if headings.count >= headingLimit { break }
        }

        // 2) 首个正文段落
        var paragraph: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { if !paragraph.isEmpty { break } else { continue } }
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("!") || trimmed.hasPrefix("[!")
                || trimmed.hasPrefix("<") || trimmed.hasPrefix("|") || trimmed.hasPrefix("```") {
                continue
            }
            paragraph.append(trimmed)
            if paragraph.joined().count > 160 { break }
        }

        var parts: [String] = []
        if !headings.isEmpty {
            parts.append("文档结构：\(headings.joined(separator: " · "))")
        }
        if !paragraph.isEmpty {
            let joined = paragraph.joined(separator: " ")
            parts.append("开篇介绍：\(firstSentence(joined))")
        }
        if parts.isEmpty {
            parts.append("README 内容较短，建议直接打开仓库查看。")
        }
        return parts.joined(separator: "\n\n")
    }

    // MARK: 工具


    /// README 里的第一张配图（用于详情页预览）
    static func firstImageURL(in markdown: String) -> URL? {
        let patterns = [
            "!\\[[^\\]]*\\]\\((https?://[^)\\s]+)\\)",
            "<img[^>]+src=[\"'](https?://[^\"']+)[\"']"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
            guard let match = regex.firstMatch(in: markdown, options: [], range: range),
                  match.numberOfRanges > 1,
                  let urlRange = Range(match.range(at: 1), in: markdown) else { continue }
            let raw = String(markdown[urlRange])
            if let url = URL(string: raw) { return url }
        }
        return nil
    }

    // MARK: README 原文摘录（先展示原文，非中文再交给 AI 翻译）

    /// 从 markdown 里抽出可读正文：去代码块 / 图片 / badge / HTML / 表格，保留标题与段落
    static func readmeExcerpt(_ markdown: String, maxChars: Int = 4000) -> String {
        var kept: [String] = []
        var inFence = false

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence { continue }
            if line.isEmpty {
                if kept.last?.isEmpty == false { kept.append("") }
                continue
            }
            if line.hasPrefix("![") || line.hasPrefix("[![") || line.hasPrefix("<") || line.hasPrefix("|") {
                continue
            }
            if line.lowercased().contains("shields.io") || line.lowercased().contains("badge") {
                continue
            }
            if line.hasPrefix("#") {
                let title = line.replacingOccurrences(of: "#", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && title.count <= 40 {
                    kept.append(title)
                }
                continue
            }
            kept.append(line)
        }

        var text = kept.joined(separator: "\n")
        // 去掉 GitHub 短代码表情（:grin: / :rocket: 这类）
        text = text.replacingOccurrences(
            of: "(:[a-zA-Z0-9_+\\-]{2,30}:)",
            with: "",
            options: .regularExpression
        )
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "" }
        if text.count > maxChars {
            let end = text.index(text.startIndex, offsetBy: maxChars)
            text = String(text[..<end]) + "…"
        }
        return text
    }
    /// 是否以中文为主（汉字占字母类字符 30% 以上即视为中文）。
    /// 韩文/日文/英文都会返回 false，从而触发翻译。
    static func isMostlyChinese(_ text: String) -> Bool {
        var han = 0
        var letters = 0
        for scalar in text.unicodeScalars {
            if CharacterSet.letters.contains(scalar) {
                letters += 1
                if (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value) {
                    han += 1
                }
            }
        }
        guard letters > 0 else { return false }
        return Double(han) / Double(letters) > 0.30
    }

    /// 是否包含中日韩统一表意文字
    static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
            || (0x3400...0x4DBF).contains(scalar.value)
        }
    }

    /// 取第一句（按中英文句号切）
    static func firstSentence(_ text: String, maxLength: Int = 90) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for separator in ["。", "！", "？", ". ", "! ", "? "] {
            if let range = trimmed.range(of: separator) {
                let sentence = String(trimmed[..<range.upperBound])
                if sentence.count >= 8 { return sentence }
            }
        }
        if trimmed.count > maxLength {
            let end = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
            return String(trimmed[..<end]) + "…"
        }
        return trimmed
    }
}
