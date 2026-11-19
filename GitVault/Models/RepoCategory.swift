//
//  RepoCategory.swift
//  GitVault
//
//  第一层分类：6 大主题场景。这是全 App 的导航骨架。
//

import SwiftUI

enum RepoCategory: String, CaseIterable, Identifiable, Codable {
    case ai
    case tooling
    case frontend
    case backend
    case mobile
    case learning

    var id: String { rawValue }

    /// 中文主题名
    var title: String {
        switch self {
        case .ai: return "AI 与智能"
        case .tooling: return "开发工具链"
        case .frontend: return "前端与设计"
        case .backend: return "后端与架构"
        case .mobile: return "移动与跨端"
        case .learning: return "学习与资源"
        }
    }

    var emoji: String {
        switch self {
        case .ai: return "🚀"
        case .tooling: return "🛠"
        case .frontend: return "🎨"
        case .backend: return "⚙️"
        case .mobile: return "📱"
        case .learning: return "🧪"
        }
    }

    /// 一句话定位，出现在分类页卡片与 Tab 提示
    var subtitle: String {
        switch self {
        case .ai: return "LLM · Agent · 视觉 · RAG"
        case .tooling: return "CLI · 插件 · 构建 · CI"
        case .frontend: return "组件库 · 动效 · 设计系统"
        case .backend: return "数据库 · 中间件 · 云原生"
        case .mobile: return "iOS · Android · 鸿蒙"
        case .learning: return "教程 · 清单 · 面试 · 算法"
        }
    }

    /// 分类封面渐变（每类一个独立色相区间，保持整体紫蓝基调）
    var gradient: [Color] {
        switch self {
        case .ai: return [Color(hex: 0x6E7BFF), Color(hex: 0xA66CFF)]
        case .tooling: return [Color(hex: 0x4F8DFD), Color(hex: 0x6EE7FF)]
        case .frontend: return [Color(hex: 0xA66CFF), Color(hex: 0xFF6FB5)]
        case .backend: return [Color(hex: 0x3A4A8C), Color(hex: 0x6E7BFF)]
        case .mobile: return [Color(hex: 0x5B6CFF), Color(hex: 0x3DDC97)]
        case .learning: return [Color(hex: 0xFF9A5A), Color(hex: 0xFF6FB5)]
        }
    }

    /// SF Symbol（用于胶囊快捷入口）
    var symbol: String {
        switch self {
        case .ai: return "sparkles"
        case .tooling: return "wrench.and.screwdriver.fill"
        case .frontend: return "paintbrush.pointed.fill"
        case .backend: return "server.rack"
        case .mobile: return "iphone.gen3"
        case .learning: return "book.closed.fill"
        }
    }

    /// 规则分类器关键词（阶段 2 使用；阶段 1 先随模型一起落地，保证契约稳定）
    var keywords: [String] {
        switch self {
        case .ai:
            return ["llm", "gpt", "agent", "diffusion", "rag", "transformer", "embedding",
                    "inference", "vision", "cuda", "finetune", "prompt", "ml", "ai",
                    "大模型", "推理", "多模态"]
        case .tooling:
            return ["cli", "terminal", "vscode", "plugin", "build", "bundler", "linter",
                    "devops", "ci", "docker", "kubernetes", "git", "shell", "workflow",
                    "工具", "构建", "命令行"]
        case .frontend:
            return ["react", "vue", "svelte", "css", "tailwind", "component", "ui",
                    "design-system", "animation", "nextjs", "vite", "web",
                    "组件", "设计系统", "动效"]
        case .backend:
            return ["database", "redis", "kafka", "microservice", "grpc", "distributed",
                    "postgres", "mysql", "storage", "server", "cloud", "native",
                    "数据库", "微服务", "分布式"]
        case .mobile:
            return ["ios", "swift", "swiftui", "android", "kotlin", "flutter", "react-native",
                    "harmony", "compose", "mobile", "app",
                    "移动端", "跨端", "鸿蒙"]
        case .learning:
            return ["awesome", "tutorial", "guide", "course", "interview", "algorithm",
                    "book", "roadmap", "leetcode", "learning", "cheatsheet",
                    "教程", "面试", "算法", "清单"]
        }
    }

    /// 主题强调色（文字/图标着色）
    var tint: Color { gradient.first ?? DS.accent }
}

extension RepoCategory {
    /// 轻量映射：从 GitHub topics 里命中最多的分类
    static func infer(fromTopics topics: [String], description: String?, language: String?) -> RepoCategory {
        var scores: [RepoCategory: Int] = [:]
        let topicsLower = topics.map { $0.lowercased() }
        let descLower = (description ?? "").lowercased()

        for category in allCases {
            var score = 0
            for keyword in category.keywords {
                if topicsLower.contains(where: { $0.contains(keyword) }) { score += 3 }
                if descLower.contains(keyword) { score += 1 }
            }
            scores[category] = score
        }

        if let best = scores.max(by: { $0.value < $1.value }), best.value > 0 {
            return best.key
        }
        // 兜底：按主语言推断
        if let language = language?.lowercased() {
            if ["swift", "kotlin", "dart", "objective-c"].contains(language) { return .mobile }
            if ["typescript", "javascript", "css", "html"].contains(language) { return .frontend }
            if ["go", "java", "rust", "c++", "c"].contains(language) { return .backend }
            if ["python", "jupyter notebook"].contains(language) { return .ai }
        }
        return .learning
    }
}
