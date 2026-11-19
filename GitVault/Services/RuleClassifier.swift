//
//  RuleClassifier.swift
//  GitVault
//
//  内置「规则分类器」：不联网、纯本地，把仓库映射到 6 大主题 + 四组智能标签。
//  AI 版实现在 LLMClassifier；两者共同满足 LLMClassifierProtocol 的语义约定。
//

import Foundation

enum RuleClassifier {

    // MARK: 状态：🔥 飙升 / 🌱 新星 / 🏆 经典 / 💤 低活跃

    static func activity(stars: Int, pushedAt: Date?) -> ActivityTag {
        let now = Date()
        let idleDays = pushedAt.map { now.timeIntervalSince($0) / 86_400 } ?? 999

        // 半年没动的，一律低活跃
        if idleDays > 180 { return .dormant }
        // 高星 + 仍在维护 = 经典
        if stars >= 20_000 && idleDays <= 30 { return .classic }
        // 30 天内活跃的中等星项目 = 飙升
        if idleDays <= 30 && stars >= 1_000 { return .rising }
        // 近期新建 / 小星量但活跃 = 新星
        if idleDays <= 14 && stars < 1_000 { return .newStar }
        if stars >= 20_000 { return .classic }
        return idleDays <= 60 ? .rising : .dormant
    }

    // MARK: 用途：⚡️ 可直接用 / 📚 需学习 / 🔖 仅供参考

    static func usage(name: String, topics: [String], stars: Int) -> UsageTag {
        let lowered = ([name] + topics).map { $0.lowercased() }
        let joined = lowered.joined(separator: " ")

        // 学习 / 资源类关键词
        let learningKeys = ["awesome", "tutorial", "guide", "roadmap", "interview", "book",
                            "course", "cheatsheet", "list", "examples", "learning", "教程"]
        if learningKeys.contains(where: { joined.contains($0) }) { return .referenceOnly }

        // 框架 / 引擎级项目，接入成本高
        let heavyKeys = ["framework", "engine", "compiler", "kernel", "runtime", "vm",
                         "distributed", "database", "浏览器", "编译器", "数据库"]
        if heavyKeys.contains(where: { joined.contains($0) }) { return .needsLearning }

        // 工具 / 库 / 模板，开箱即用
        let readyKeys = ["cli", "tool", "library", "sdk", "component", "ui", "template",
                         "starter", "plugin", "client", "wrapper", "工具", "组件", "模板"]
        if readyKeys.contains(where: { joined.contains($0) }) { return .readyToUse }

        return stars >= 5_000 ? .readyToUse : .needsLearning
    }
}
