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
        case .ai: return NSLocalizedString("AI 与智能", comment: "")
        case .data: return NSLocalizedString("数据与 AI 工程", comment: "")
        case .tooling: return NSLocalizedString("开发工具链", comment: "")
        case .frontend: return NSLocalizedString("前端与设计", comment: "")
        case .backend: return NSLocalizedString("后端与架构", comment: "")
        case .database: return NSLocalizedString("数据库与存储", comment: "")
        case .mobile: return NSLocalizedString("移动与跨端", comment: "")
        case .systems: return NSLocalizedString("系统与底层", comment: "")
        case .security: return NSLocalizedString("安全与隐私", comment: "")
        case .learning: return NSLocalizedString("学习与资源", comment: "")
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
        case .ai: return NSLocalizedString("LLM · Agent · 视觉 · RAG", comment: "")
        case .data: return NSLocalizedString("管道 · MLOps · 分析 · 流处理", comment: "")
        case .tooling: return NSLocalizedString("CLI · 插件 · 构建 · CI", comment: "")
        case .frontend: return NSLocalizedString("组件库 · 动效 · 设计系统", comment: "")
        case .backend: return NSLocalizedString("微服务 · 中间件 · 云原生", comment: "")
        case .database: return NSLocalizedString("关系型 · 缓存 · 搜索 · 时序", comment: "")
        case .mobile: return NSLocalizedString("iOS · Android · 鸿蒙", comment: "")
        case .systems: return NSLocalizedString("内核 · 嵌入式 · 运行时", comment: "")
        case .security: return NSLocalizedString("渗透 · 加密 · 供应链", comment: "")
        case .learning: return NSLocalizedString("教程 · 清单 · 面试 · 算法", comment: "")
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
                RepoSubcategory(id: "ai.llm", title: NSLocalizedString("大模型", comment: ""), topics: ["llm", "gpt", "transformer"], languages: []),
                RepoSubcategory(id: "ai.agent", title: "Agent", topics: ["agent", "agents", "autonomous-agents"], languages: []),
                RepoSubcategory(id: "ai.cv", title: NSLocalizedString("视觉生成", comment: ""), topics: ["stable-diffusion", "image-generation", "computer-vision"], languages: []),
                RepoSubcategory(id: "ai.rag", title: NSLocalizedString("RAG 检索", comment: ""), topics: ["rag", "vector-database", "embedding"], languages: [])
            ]
        case .data:
            return [
                RepoSubcategory(id: "data.pipeline", title: NSLocalizedString("数据管道", comment: ""), topics: ["etl", "airflow", "dbt"], languages: []),
                RepoSubcategory(id: "data.mlops", title: "MLOps", topics: ["mlops", "feature-store", "model-serving"], languages: []),
                RepoSubcategory(id: "data.stream", title: NSLocalizedString("流处理", comment: ""), topics: ["kafka", "flink", "stream-processing"], languages: []),
                RepoSubcategory(id: "data.bi", title: NSLocalizedString("分析看板", comment: ""), topics: ["analytics", "business-intelligence", "dashboard"], languages: [])
            ]
        case .tooling:
            return [
                RepoSubcategory(id: "tool.cli", title: NSLocalizedString("命令行", comment: ""), topics: ["cli", "command-line", "terminal"], languages: ["go", "rust", "shell"]),
                RepoSubcategory(id: "tool.editor", title: NSLocalizedString("编辑器插件", comment: ""), topics: ["vscode-extension", "neovim", "jetbrains-plugin"], languages: []),
                RepoSubcategory(id: "tool.build", title: NSLocalizedString("构建打包", comment: ""), topics: ["build-tool", "bundler", "monorepo"], languages: []),
                RepoSubcategory(id: "tool.devops", title: "DevOps", topics: ["devops", "docker", "github-actions"], languages: [])
            ]
        case .frontend:
            return [
                RepoSubcategory(id: "fe.ui", title: NSLocalizedString("组件库", comment: ""), topics: ["ui-components", "component-library", "design-system"], languages: []),
                RepoSubcategory(id: "fe.motion", title: NSLocalizedString("动效", comment: ""), topics: ["animation", "motion", "gsap"], languages: []),
                RepoSubcategory(id: "fe.framework", title: NSLocalizedString("跨端框架", comment: ""), topics: ["react", "vue", "svelte"], languages: []),
                RepoSubcategory(id: "fe.style", title: NSLocalizedString("样式方案", comment: ""), topics: ["css", "tailwindcss", "styling"], languages: [])
            ]
        case .backend:
            return [
                RepoSubcategory(id: "be.micro", title: NSLocalizedString("微服务", comment: ""), topics: ["microservices", "grpc", "api-gateway"], languages: []),
                RepoSubcategory(id: "be.mq", title: NSLocalizedString("消息队列", comment: ""), topics: ["kafka", "message-queue", "rabbitmq"], languages: []),
                RepoSubcategory(id: "be.cloud", title: NSLocalizedString("云原生", comment: ""), topics: ["kubernetes", "serverless", "cloud-native"], languages: []),
                RepoSubcategory(id: "be.framework", title: NSLocalizedString("服务框架", comment: ""), topics: ["web-framework", "backend", "rest-api"], languages: [])
            ]
        case .database:
            return [
                RepoSubcategory(id: "db.sql", title: NSLocalizedString("关系型", comment: ""), topics: ["postgresql", "mysql", "sql"], languages: []),
                RepoSubcategory(id: "db.kv", title: NSLocalizedString("键值与缓存", comment: ""), topics: ["redis", "key-value", "memcached"], languages: []),
                RepoSubcategory(id: "db.search", title: NSLocalizedString("搜索引擎", comment: ""), topics: ["search-engine", "elasticsearch", "full-text-search"], languages: []),
                RepoSubcategory(id: "db.ts", title: NSLocalizedString("时序与列存", comment: ""), topics: ["timeseries", "clickhouse", "olap"], languages: [])
            ]
        case .mobile:
            return [
                RepoSubcategory(id: "mob.ios", title: "iOS", topics: ["ios", "swiftui"], languages: ["swift", "objective-c"]),
                RepoSubcategory(id: "mob.android", title: "Android", topics: ["android", "jetpack-compose"], languages: ["kotlin", "java"]),
                RepoSubcategory(id: "mob.flutter", title: "Flutter", topics: ["flutter"], languages: ["dart"]),
                RepoSubcategory(id: "mob.rn", title: "React Native", topics: ["react-native"], languages: []),
                RepoSubcategory(id: "mob.harmony", title: NSLocalizedString("鸿蒙", comment: ""), topics: ["harmonyos", "arkts"], languages: [])
            ]
        case .systems:
            return [
                RepoSubcategory(id: "sys.kernel", title: NSLocalizedString("内核与驱动", comment: ""), topics: ["kernel", "driver", "ebpf"], languages: ["c", "c++", "rust"]),
                RepoSubcategory(id: "sys.embedded", title: NSLocalizedString("嵌入式", comment: ""), topics: ["embedded", "firmware", "rtos"], languages: []),
                RepoSubcategory(id: "sys.runtime", title: NSLocalizedString("运行时", comment: ""), topics: ["wasm", "virtual-machine", "interpreter"], languages: []),
                RepoSubcategory(id: "sys.perf", title: NSLocalizedString("性能与调试", comment: ""), topics: ["profiling", "debugging", "benchmark"], languages: [])
            ]
        case .security:
            return [
                RepoSubcategory(id: "sec.pentest", title: NSLocalizedString("渗透测试", comment: ""), topics: ["pentest", "exploit", "vulnerability"], languages: []),
                RepoSubcategory(id: "sec.crypto", title: NSLocalizedString("加密与隐私", comment: ""), topics: ["cryptography", "encryption", "privacy"], languages: []),
                RepoSubcategory(id: "sec.chain", title: NSLocalizedString("供应链安全", comment: ""), topics: ["sbom", "supply-chain", "vulnerability-scanner"], languages: []),
                RepoSubcategory(id: "sec.tools", title: NSLocalizedString("安全工具", comment: ""), topics: ["security-tools", "ctf", "forensics"], languages: [])
            ]
        case .learning:
            return [
                RepoSubcategory(id: "learn.list", title: NSLocalizedString("Awesome 清单", comment: ""), topics: ["awesome-list", "awesome"], languages: []),
                RepoSubcategory(id: "learn.tutorial", title: NSLocalizedString("教程", comment: ""), topics: ["tutorial", "course", "guide"], languages: []),
                RepoSubcategory(id: "learn.interview", title: NSLocalizedString("面试算法", comment: ""), topics: ["interview", "leetcode", "algorithms"], languages: []),
                RepoSubcategory(id: "learn.book", title: NSLocalizedString("书籍", comment: ""), topics: ["books", "ebook", "free-programming-books"], languages: [])
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
