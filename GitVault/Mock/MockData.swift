//
//  MockData.swift
//  GitVault
//
//  阶段 1 的预览 / 占位数据。全部为真实仓库 + 人工撰写的中文摘要，
//  阶段 2 接入 GitHub API 后，这里只保留 #Preview 用途。
//

import SwiftUI

enum MockData {

    // MARK: 主数据集

    static let repos: [ShowcaseRepo] = [
        ShowcaseRepo(
            id: "ollama/ollama",
            owner: "ollama",
            name: "ollama",
            summary: "一条命令在本地跑起 Llama、Qwen、DeepSeek 等大模型，自带模型仓库与 OpenAI 兼容接口。",
            language: "Go",
            stars: 128_400,
            starDeltaToday: 486,
            forks: 10_200,
            openIssues: 1_320,
            category: .ai,
            activity: .rising,
            usage: .readyToUse,
            license: .mit,
            gradient: [Color(hex: 0x6E7BFF), Color(hex: 0xA66CFF)],
            isFeatured: true
        ),
        ShowcaseRepo(
            id: "langchain-ai/langchain",
            owner: "langchain-ai",
            name: "langchain",
            summary: "构建 LLM 应用的脚手架：链式调用、工具、记忆、RAG 检索一站式封装，生态最全。",
            language: "Python",
            stars: 96_800,
            starDeltaToday: 214,
            forks: 15_600,
            openIssues: 2_480,
            category: .ai,
            activity: .classic,
            usage: .needsLearning,
            license: .mit,
            gradient: [Color(hex: 0x5B6CFF), Color(hex: 0x8F6BFF)],
            isFeatured: false
        ),
        ShowcaseRepo(
            id: "comfyanonymous/ComfyUI",
            owner: "comfyanonymous",
            name: "ComfyUI",
            summary: "节点式扩散模型工作流，出图全流程可视化编排，Stable Diffusion 玩家的生产力核心。",
            language: "Python",
            stars: 68_900,
            starDeltaToday: 328,
            forks: 7_600,
            openIssues: 1_940,
            category: .ai,
            activity: .rising,
            usage: .needsLearning,
            license: .gpl,
            gradient: [Color(hex: 0xA66CFF), Color(hex: 0xFF6FB5)],
            isFeatured: true
        ),
        ShowcaseRepo(
            id: "apple/swift",
            owner: "apple",
            name: "swift",
            summary: "Apple 官方 Swift 语言与标准库，源码级学习 Swift 并发、内存模型的最佳去处。",
            language: "C++",
            stars: 68_200,
            starDeltaToday: 42,
            forks: 10_500,
            openIssues: 6_800,
            category: .mobile,
            activity: .classic,
            usage: .referenceOnly,
            license: .apache,
            gradient: [Color(hex: 0xF05138), Color(hex: 0xFF9A5A)],
            isFeatured: false
        ),
        ShowcaseRepo(
            id: "flutter/flutter",
            owner: "flutter",
            name: "flutter",
            summary: "一套 Dart 代码同时跑 iOS、Android、Web、桌面，自绘引擎带来高度一致的 UI 表现。",
            language: "Dart",
            stars: 168_500,
            starDeltaToday: 96,
            forks: 27_900,
            openIssues: 12_600,
            category: .mobile,
            activity: .classic,
            usage: .needsLearning,
            license: .none,
            gradient: [Color(hex: 0x3DB2FF), Color(hex: 0x3DDC97)],
            isFeatured: false
        ),
        ShowcaseRepo(
            id: "vercel/next.js",
            owner: "vercel",
            name: "next.js",
            summary: "React 全栈框架，App Router + Server Actions + 流式渲染，现代 Web 事实标准。",
            language: "TypeScript",
            stars: 132_700,
            starDeltaToday: 132,
            forks: 28_400,
            openIssues: 2_900,
            category: .frontend,
            activity: .rising,
            usage: .readyToUse,
            license: .mit,
            gradient: [Color(hex: 0x0B0E14), Color(hex: 0x6E7BFF)],
            isFeatured: true
        ),
        ShowcaseRepo(
            id: "shadcn-ui/ui",
            owner: "shadcn-ui",
            name: "ui",
            summary: "复制粘贴即用的 React 组件集合，不加依赖、可完全改样式，设计系统起手式的天花板。",
            language: "TypeScript",
            stars: 74_300,
            starDeltaToday: 268,
            forks: 4_500,
            openIssues: 1_200,
            category: .frontend,
            activity: .rising,
            usage: .readyToUse,
            license: .mit,
            gradient: [Color(hex: 0x2B2F3A), Color(hex: 0x6E7BFF)],
            isFeatured: false
        ),
        ShowcaseRepo(
            id: "tailwindlabs/tailwindcss",
            owner: "tailwindlabs",
            name: "tailwindcss",
            summary: "原子化 CSS 框架，用类名拼装样式，配合设计令牌可做出极高一致性的界面。",
            language: "TypeScript",
            stars: 84_600,
            starDeltaToday: 78,
            forks: 4_300,
            openIssues: 90,
            category: .frontend,
            activity: .classic,
            usage: .readyToUse,
            license: .mit,
            gradient: [Color(hex: 0x38BDF8), Color(hex: 0x6E7BFF)],
            isFeatured: false
        ),
        ShowcaseRepo(
            id: "rust-lang/rust",
            owner: "rust-lang",
            name: "rust",
            summary: "所有权模型驱动的系统级语言，无 GC 也能内存安全，基础设施领域的长期赢家。",
            language: "Rust",
            stars: 102_300,
            starDeltaToday: 64,
            forks: 13_100,
            openIssues: 10_200,
            category: .backend,
            activity: .classic,
            usage: .needsLearning,
            license: .apache,
            gradient: [Color(hex: 0x8A4B2A), Color(hex: 0xDEA584)],
            isFeatured: false
        ),
        ShowcaseRepo(
            id: "supabase/supabase",
            owner: "supabase",
            name: "supabase",
            summary: "开源版 Firebase：Postgres + 鉴权 + 对象存储 + 实时订阅，一天搭出后端。",
            language: "TypeScript",
            stars: 78_900,
            starDeltaToday: 156,
            forks: 8_100,
            openIssues: 480,
            category: .backend,
            activity: .rising,
            usage: .readyToUse,
            license: .apache,
            gradient: [Color(hex: 0x1FBF75), Color(hex: 0x3DDC97)],
            isFeatured: true
        ),
        ShowcaseRepo(
            id: "tauri-apps/tauri",
            owner: "tauri-apps",
            name: "tauri",
            summary: "用 Web 前端 + Rust 内核打包桌面应用，体积只有 Electron 的十分之一。",
            language: "Rust",
            stars: 88_200,
            starDeltaToday: 143,
            forks: 2_700,
            openIssues: 820,
            category: .tooling,
            activity: .rising,
            usage: .needsLearning,
            license: .apache,
            gradient: [Color(hex: 0x2B2F3A), Color(hex: 0xFFC940)],
            isFeatured: false
        ),
        ShowcaseRepo(
            id: "oven-sh/bun",
            owner: "oven-sh",
            name: "bun",
            summary: "集运行时、包管理器、测试器、打包器于一体的 JS 全家桶，启动速度碾压 Node。",
            language: "Zig",
            stars: 76_400,
            starDeltaToday: 189,
            forks: 2_900,
            openIssues: 3_400,
            category: .tooling,
            activity: .rising,
            usage: .readyToUse,
            license: .mit,
            gradient: [Color(hex: 0xFFF3D6), Color(hex: 0xFFB020)],
            isFeatured: false
        ),
        ShowcaseRepo(
            id: "jwasham/coding-interview-university",
            owner: "jwasham",
            name: "coding-interview-university",
            summary: "从零补齐计算机基础的完整学习清单，按周排期的面试备战路线。",
            language: "Markdown",
            stars: 312_600,
            starDeltaToday: 87,
            forks: 76_400,
            openIssues: 60,
            category: .learning,
            activity: .classic,
            usage: .referenceOnly,
            license: .none,
            gradient: [Color(hex: 0xFF9A5A), Color(hex: 0xFF6FB5)],
            isFeatured: false
        ),
        ShowcaseRepo(
            id: "kamranahmedse/developer-roadmap",
            owner: "kamranahmedse",
            name: "developer-roadmap",
            summary: "前端 / 后端 / DevOps 等方向的技能路线图，每个节点都附学习资源。",
            language: "TypeScript",
            stars: 298_400,
            starDeltaToday: 118,
            forks: 39_200,
            openIssues: 40,
            category: .learning,
            activity: .classic,
            usage: .referenceOnly,
            license: .none,
            gradient: [Color(hex: 0x6E7BFF), Color(hex: 0x3DDC97)],
            isFeatured: false
        )
    ]

    // MARK: 派生切片

    static var featured: [ShowcaseRepo] {
        repos.filter(\.isFeatured)
    }

    static var trending: [ShowcaseRepo] {
        repos
            .filter { $0.starDeltaToday > 0 }
            .sorted { $0.starDeltaToday > $1.starDeltaToday }
    }

    /// 「为你推荐」：阶段 1 用主题互补规则挑选，阶段 2 换成协同过滤
    static var forYou: [ShowcaseRepo] {
        Array(trending.dropFirst(4).prefix(6))
    }

    static func repos(in category: RepoCategory) -> [ShowcaseRepo] {
        repos.filter { $0.category == category }
    }

    static func count(in category: RepoCategory) -> Int {
        repos(in: category).count
    }

    // MARK: 搜索

    static let hotKeywords = ["AI Agent", "SwiftUI", "RAG", "Rust CLI", "设计系统", "LeetCode"]

    static let defaultSearchHistory = ["ollama", "swiftui 动画", "开源向量数据库"]

    // MARK: 我的文件夹（阶段 4 改为 SwiftData 实体）

    static let vaultFolders: [MockFolder] = [
        MockFolder(name: "AI 工具箱", emoji: "🤖", count: 12),
        MockFolder(name: "iOS 参考", emoji: "📱", count: 8),
        MockFolder(name: "待研究的后端", emoji: "🧱", count: 5)
    ]
}

/// 阶段 1 的文件夹展示模型；阶段 4 换成 SwiftData 实体 VaultFolder
struct MockFolder: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let emoji: String
    let count: Int
}
