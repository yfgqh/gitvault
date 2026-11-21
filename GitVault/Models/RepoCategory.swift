//
//  RepoCategory.swift
//  GitVault
//
//  第一层分类：10 大主题场景；并为每类提供「二级子分类」与「抓取用 topic」。
//
//  重要：GitHub 搜索里多个 `topic:` 是 AND 关系（必须同时具备），
//  所以一个分类不能靠拼多个 topic 查询，否则结果恒为 0。
//  这里改为「每个子分类一个代表 topic，逐个查询后合并」。
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
    case data
    case tooling
    case frontend
    case backend
    case database
    case mobile
    case systems
    case security
    case learning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ai: return "AI 与智能"
        case .data: return "数据与 AI 工程"
        case .tooling: return "开发工具链"
        case .frontend: return "前端与设计"
        case .backend: return "后端与架构"
        case .database: return "数据库与存储"
        case .mobile: return "移动与跨端"
        case .systems: return "系统与底层"
        case .security: return "安全与隐私"
        case .learning: return "学习与资源"
        }
    }

    var emoji: String {
        switch self {
        case .ai: return "🚀"
        case .data: return "📊"
        case .tooling: return "🛠"
        case .frontend: return "🎨"
        case .backend: return "⚙️"
        case .database: return "🗄"
        case .mobile: return "📱"
        case .systems: return "🧩"
        case .security: return "🔐"
        case .learning: return "🧪"
        }
    }

    var subtitle: String {
        switch self {
        case .ai: return "LLM · Agent · 视觉 · RAG"
        case .data: return "管道 · MLOps · 分析 · 流处理"
        case .tooling: return "CLI · 插件 · 构建 · CI"
        case .frontend: return "组件库 · 动效 · 设计系统"
        case .backend: return "微服务 · 中间件 · 云原生"
        case .database: return "关系型 · 缓存 · 搜索 · 时序"
        case .mobile: return "iOS · Android · 鸿蒙"
        case .systems: return "内核 · 嵌入式 · 运行时"
        case .security: return "渗透 · 加密 · 供应链"
        case .learning: return "教程 · 清单 · 面试 · 算法"
        }
    }

    var gradient: [Color] {
        switch self {
        case .ai: return [Color(hex: 0x6E7BFF), Color(hex: 0xA66CFF)]
        case .data: return [Color(hex: 0x22D3EE), Color(hex: 0x3B82F6)]
        case .tooling: return [Color(hex: 0x4F8DFD), Color(hex: 0x6EE7FF)]
        case .frontend: return [Color(hex: 0xA66CFF), Color(hex: 0xFF6FB5)]
        case .backend: return [Color(hex: 0x3A4A8C), Color(hex: 0x6E7BFF)]
        case .database: return [Color(hex: 0x10B981), Color(hex: 0x0EA5E9)]
        case .mobile: return [Color(hex: 0x5B6CFF), Color(hex: 0x3DDC97)]
        case .systems: return [Color(hex: 0x64748B), Color(hex: 0x1E293B)]
        case .security: return [Color(hex: 0xEF4444), Color(hex: 0xF59E0B)]
        case .learning: return [Color(hex: 0xFF9A5A), Color(hex: 0xFF6FB5)]
        }
    }

    var symbol: String {
        switch self {
        case .ai: return "sparkles"
        case .data: return "chart.bar.xaxis"
        case .tooling: return "wrench.and.screwdriver.fill"
        case .frontend: return "paintbrush.pointed.fill"
        case .backend: return "server.rack"
        case .database: return "cylinder.split.1x2"
        case .mobile: return "iphone.gen3"
        case .systems: return "cpu"
        case .security: return "lock.shield.fill"
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
        case .data:
            return ["data-engineering", "etl", "mlops", "analytics", "pipeline", "airflow",
                    "dbt", "spark", "flink", "dataframe", "data-science", "feature-store",
                    "数据", "管道", "特征"]
        case .tooling:
            return ["cli", "terminal", "vscode", "plugin", "build", "bundler", "linter",
                    "devops", "ci", "docker", "git", "shell", "workflow",
                    "工具", "构建", "命令行"]
        case .frontend:
            return ["react", "vue", "svelte", "css", "tailwind", "component", "ui",
                    "design-system", "animation", "nextjs", "vite", "web",
                    "组件", "设计系统", "动效"]
        case .backend:
            return ["microservice", "grpc", "distributed", "server", "cloud", "cloud-native",
                    "kubernetes", "message-queue", "api-gateway", "rpc",
                    "微服务", "分布式", "云原生"]
        case .database:
            return ["database", "sql", "postgresql", "postgres", "mysql", "redis", "sqlite",
                    "key-value", "search-engine", "elasticsearch", "timeseries", "olap",
                    "数据库", "缓存", "搜索引擎"]
        case .mobile:
            return ["ios", "swift", "swiftui", "android", "kotlin", "flutter", "react-native",
                    "harmonyos", "compose", "mobile", "app",
                    "移动端", "跨端", "鸿蒙"]
        case .systems:
            return ["kernel", "driver", "ebpf", "embedded", "firmware", "rtos", "wasm",
                    "virtual-machine", "interpreter", "compiler", "profiling", "benchmark",
                    "内核", "嵌入式", "运行时"]
        case .security:
            return ["security", "cybersecurity", "pentest", "privacy", "encryption",
                    "cryptography", "vulnerability", "ctf", "forensics", "sbom",
                    "安全", "渗透", "加密"]
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
        case .data: return ["data-engineering", "etl", "mlops"]
        case .tooling: return ["cli", "devtools", "vscode-extension"]
        case .frontend: return ["react", "ui-components", "css"]
        case .backend: return ["microservices", "kubernetes", "grpc"]
        case .database: return ["database", "postgresql", "search-engine"]
        case .mobile: return ["ios", "android", "flutter"]
        case .systems: return ["kernel", "embedded", "wasm"]
        case .security: return ["security", "cybersecurity", "pentest"]
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
        case .data:
            return [
                RepoSubcategory(id: "data.pipeline", title: "数据管道", topics: ["etl", "airflow", "dbt"], languages: []),
                RepoSubcategory(id: "data.mlops", title: "MLOps", topics: ["mlops", "feature-store", "model-serving"], languages: []),
                RepoSubcategory(id: "data.stream", title: "流处理", topics: ["kafka", "flink", "stream-processing"], languages: []),
                RepoSubcategory(id: "data.bi", title: "分析看板", topics: ["analytics", "business-intelligence", "dashboard"], languages: [])
            ]
        case .tooling:
            return [
                RepoSubcategory(id: "tool.cli", title: "命令行", topics: ["cli", "command-line", "terminal"], languages: ["go", "rust", "shell"]),
                RepoSubcategory(id: "tool.editor", title: "编辑器插件", topics: ["vscode-extension", "neovim", "jetbrains-plugin"], languages: []),
                RepoSubcategory(id: "tool.build", title: "构建打包", topics: ["build-tool", "bundler", "monorepo"], languages: []),
                RepoSubcategory(id: "tool.devops", title: "DevOps", topics: ["devops", "docker", "github-actions"], languages: [])
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
                RepoSubcategory(id: "be.micro", title: "微服务", topics: ["microservices", "grpc", "api-gateway"], languages: []),
                RepoSubcategory(id: "be.mq", title: "消息队列", topics: ["kafka", "message-queue", "rabbitmq"], languages: []),
                RepoSubcategory(id: "be.cloud", title: "云原生", topics: ["kubernetes", "serverless", "cloud-native"], languages: []),
                RepoSubcategory(id: "be.framework", title: "服务框架", topics: ["web-framework", "backend", "rest-api"], languages: [])
            ]
        case .database:
            return [
                RepoSubcategory(id: "db.sql", title: "关系型", topics: ["postgresql", "mysql", "sql"], languages: []),
                RepoSubcategory(id: "db.kv", title: "键值与缓存", topics: ["redis", "key-value", "memcached"], languages: []),
                RepoSubcategory(id: "db.search", title: "搜索引擎", topics: ["search-engine", "elasticsearch", "full-text-search"], languages: []),
                RepoSubcategory(id: "db.ts", title: "时序与列存", topics: ["timeseries", "clickhouse", "olap"], languages: [])
            ]
        case .mobile:
            return [
                RepoSubcategory(id: "mob.ios", title: "iOS", topics: ["ios", "swiftui"], languages: ["swift", "objective-c"]),
                RepoSubcategory(id: "mob.android", title: "Android", topics: ["android", "jetpack-compose"], languages: ["kotlin", "java"]),
                RepoSubcategory(id: "mob.flutter", title: "Flutter", topics: ["flutter"], languages: ["dart"]),
                RepoSubcategory(id: "mob.rn", title: "React Native", topics: ["react-native"], languages: []),
                RepoSubcategory(id: "mob.harmony", title: "鸿蒙", topics: ["harmonyos", "arkts"], languages: [])
            ]
        case .systems:
            return [
                RepoSubcategory(id: "sys.kernel", title: "内核与驱动", topics: ["kernel", "driver", "ebpf"], languages: ["c", "c++", "rust"]),
                RepoSubcategory(id: "sys.embedded", title: "嵌入式", topics: ["embedded", "firmware", "rtos"], languages: []),
                RepoSubcategory(id: "sys.runtime", title: "运行时", topics: ["wasm", "virtual-machine", "interpreter"], languages: []),
                RepoSubcategory(id: "sys.perf", title: "性能与调试", topics: ["profiling", "debugging", "benchmark"], languages: [])
            ]
        case .security:
            return [
                RepoSubcategory(id: "sec.pentest", title: "渗透测试", topics: ["pentest", "exploit", "vulnerability"], languages: []),
                RepoSubcategory(id: "sec.crypto", title: "加密与隐私", topics: ["cryptography", "encryption", "privacy"], languages: []),
                RepoSubcategory(id: "sec.chain", title: "供应链安全", topics: ["sbom", "supply-chain", "vulnerability-scanner"], languages: []),
                RepoSubcategory(id: "sec.tools", title: "安全工具", topics: ["security-tools", "ctf", "forensics"], languages: [])
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

    /// 2026-11 实测：`topic:<代表 topic> stars:>50` 的 total_count
    var baselineCount: Int {
        switch self {
        case .ai: return 8_714
        case .data: return 410
        case .tooling: return 7_152
        case .frontend: return 13_804
        case .backend: return 3_123
        case .database: return 3_126
        case .mobile: return 7_505
        case .systems: return 783
        case .security: return 5_446
        case .learning: return 3_995
        }
    }
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
            if ["sql", "plpgsql"].contains(language) { return .database }
        }
        return .learning
    }
}
