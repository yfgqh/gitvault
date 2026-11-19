//
//  RepoCategory.swift
//  GitVault
//
//  第一层分类：6 大主题场景；并为每类提供「二级子分类」与「抓取用 topic」。
//
//  重要：GitHub 搜索里多个 `topic:` 是 AND 关系（必须同时具备），
//  所以一个分类不能靠拼多个 topic 查询，否则结果恒为 0。
//  这里改为「每个子分类一个代表 topic，逐个查询后合并去重」。
//

import SwiftUI

struct RepoSubcategory: Identifiable, Hashable {
    let id: String
    let title: String
    /// 该子分类用于搜索的代表性 topic（GitHub 已小写）
    let topics: [String]
    /// 命中语言时也算匹配（用于本地二次过滤）
    let languages: [String]

    func matches(_ repo: ShowcaseRepo) -> Bool {
        if !topics.isEmpty {
            let repoTopics = Set(repo.topics.map { $0.lowercased() })
            if topics.contains(where: { repoTopics.contains($0) }) { return true }
        }
        if !languages.isEmpty {
            return languages.contains(repo.language.lowercased())
        }
        return false
    }
}

enum RepoCategory: String, CaseIterable, Identifiable, Codable {
    case ai
    case tooling
    case frontend
    case backend
    case mobile
    case learning

    var id: String { rawValue }

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

    /// 规则分类器关键词（英文 topic + 中文词）
    var keywords: [String] {
        switch self {
        case .ai:
            return ["llm", "gpt", "agent", "diffusion", "rag", "transformer", "embedding",
                    "inference", "vision", "cuda", "finetune", "prompt", "machine-learning",
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
                    "postgres", "mysql", "storage", "server", "cloud", "cloud-native",
                    "数据库", "微服务", "分布式"]
        case .mobile:
            return ["ios", "swift", "swiftui", "android", "kotlin", "flutter", "react-native",
                    "harmonyos", "compose", "mobile", "app",
                    "移动端", "跨端", "鸿蒙"]
        case .learning:
            return ["awesome", "tutorial", "guide", "course", "interview", "algorithm",
                    "book", "roadmap", "leetcode", "learning", "cheatsheet",
                    "教程", "面试", "算法", "清单"]
        }
    }

    /// 抓取项目时使用的代表性 topic（每个都单独查一次再合并）
    var searchTopics: [String] {
        switch self {
        case .ai: return ["llm", "machine-learning", "stable-diffusion"]
        case .tooling: return ["cli", "devtools", "vscode-extension"]
        case .frontend: return ["react", "ui-components", "css"]
        case .backend: return ["database", "microservices", "kubernetes"]
        case .mobile: return ["ios", "android", "flutter"]
        case .learning: return ["awesome-list", "tutorial", "roadmap"]
        }
    }

    /// 二级子分类：进入分类后先看到这一层，再筛项目
    var subcategories: [RepoSubcategory] {
        switch self {
        case .ai:
            return [
                RepoSubcategory(id: "ai.llm", title: "大模型", topics: ["llm", "gpt", "transformer"], languages: []),
                RepoSubcategory(id: "ai.agent", title: "Agent", topics: ["agent", "agents", "autonomous-agents"], languages: []),
                RepoSubcategory(id: "ai.cv", title: "视觉生成", topics: ["stable-diffusion", "image-generation", "computer-vision"], languages: []),
                RepoSubcategory(id: "ai.rag", title: "RAG 检索", topics: ["rag", "vector-database", "embedding"], languages: [])
            ]
        case .tooling:
            return [
                RepoSubcategory(id: "tool.cli", title: "命令行", topics: ["cli", "command-line", "terminal"], languages: ["go", "rust", "shell"]),
                RepoSubcategory(id: "tool.editor", title: "编辑器插件", topics: ["vscode-extension", "neovim", "jetbrains-plugin"], languages: []),
                RepoSubcategory(id: "tool.build", title: "构建打包", topics: ["build-tool", "bundler", "monorepo"], languages: []),
                RepoSubcategory(id: "tool.devops", title: "DevOps", topics: ["devops", "docker", "kubernetes"], languages: [])
            ]
        case .frontend:
            return [
                RepoSubcategory(id: "fe.ui", title: "组件库", topics: ["ui-components", "component-library", "design-system"], languages: []),
                RepoSubcategory(id: "fe.motion", title: "动效", topics: ["animation", "motion", "gsap"], languages: []),
                RepoSubcategory(id: "fe.framework", title: "跨端框架", topics: ["react", "vue", "svelte"], languages: []),
                RepoSubcategory(id: "fe.style", title: "样式方案", topics: ["css", "tailwindcss", "styling"], languages: [])
            ]
        case .backend:
            return [
                RepoSubcategory(id: "be.db", title: "数据库", topics: ["database", "postgresql", "sql"], languages: []),
                RepoSubcategory(id: "be.mq", title: "中间件", topics: ["kafka", "redis", "message-queue"], languages: []),
                RepoSubcategory(id: "be.micro", title: "微服务", topics: ["microservices", "grpc", "api-gateway"], languages: []),
                RepoSubcategory(id: "be.cloud", title: "云原生", topics: ["kubernetes", "serverless", "cloud-native"], languages: [])
            ]
        case .mobile:
            return [
                RepoSubcategory(id: "mob.ios", title: "iOS", topics: ["ios", "swiftui"], languages: ["swift", "objective-c"]),
                RepoSubcategory(id: "mob.android", title: "Android", topics: ["android", "jetpack-compose"], languages: ["kotlin", "java"]),
                RepoSubcategory(id: "mob.flutter", title: "Flutter", topics: ["flutter"], languages: ["dart"]),
                RepoSubcategory(id: "mob.rn", title: "React Native", topics: ["react-native"], languages: []),
                RepoSubcategory(id: "mob.harmony", title: "鸿蒙", topics: ["harmonyos", "arkts"], languages: [])
            ]
        case .learning:
            return [
                RepoSubcategory(id: "learn.list", title: "Awesome 清单", topics: ["awesome-list", "awesome"], languages: []),
                RepoSubcategory(id: "learn.tutorial", title: "教程", topics: ["tutorial", "course", "guide"], languages: []),
                RepoSubcategory(id: "learn.interview", title: "面试算法", topics: ["interview", "leetcode", "algorithms"], languages: []),
                RepoSubcategory(id: "learn.book", title: "书籍", topics: ["books", "ebook", "free-programming-books"], languages: [])
            ]
        }
    }

    var tint: Color { gradient.first ?? DS.accent }
}

extension RepoCategory {
    /// 从 GitHub topics 里命中最多的分类
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
        if let language = language?.lowercased() {
            if ["swift", "kotlin", "dart", "objective-c"].contains(language) { return .mobile }
            if ["typescript", "javascript", "css", "html"].contains(language) { return .frontend }
            if ["go", "java", "rust", "c++", "c"].contains(language) { return .backend }
            if ["python", "jupyter notebook"].contains(language) { return .ai }
        }
        return .learning
    }
}
