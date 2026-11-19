//
//  GitVaultApp.swift
//  GitVault
//
//  应用入口。启动路径做了「绝不闪退」的三级降级：
//  1) 版本化 store（GitVaultV2）——不碰阶段 1 的旧库，天然规避跨 schema 迁移崩溃
//  2) 打开失败 → 备份并删除坏库后重建
//  3) 仍失败 → 内存容器兜底，App 照常可用（收藏不落盘）
//  每一步都写 CrashReporter 日志，真机日志能在「我的 → 诊断日志」里看到。
//

import SwiftUI
import SwiftData

@main
struct GitVaultApp: App {
    /// 外观偏好（深色为默认）
    @AppStorage(AppPrefs.appearance) private var appearanceRaw: String = AppearanceMode.dark.rawValue

    /// 依赖注入容器（网络 / 鉴权 / 大模型）
    @State private var environment = AppEnvironment.live()

    private let container: ModelContainer

    init() {
        CrashReporter.install()
        CrashReporter.logSync("app init: building model container")
        container = Self.makeContainer()
        CrashReporter.logSync("app init: container ready (inMemory=\(Self.isUsingMemoryStore))")
    }

    /// 是否退化为内存库（诊断用）
    private(set) static var isUsingMemoryStore = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .preferredColorScheme(
                    (AppearanceMode(rawValue: appearanceRaw) ?? .dark).colorScheme
                )
                .tint(DS.accent)
                .onAppear {
                    CrashReporter.log("root view appeared")
                }
        }
        .modelContainer(container)
    }

    // MARK: - 容器构建

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([VaultEntry.self, VaultFolder.self])

        // 1) 版本化配置名：store 文件名为 GitVaultV2.store
        do {
            let config = ModelConfiguration("GitVaultV2", schema: schema)
            let container = try ModelContainer(for: schema, configurations: [config])
            CrashReporter.logSync("container: persistent store opened")
            return container
        } catch {
            CrashReporter.logSync("container: persistent open failed -> \(error)")
        }

        // 2) 坏库/版本冲突：挪走旧文件后重建
        removeStoreFiles()
        do {
            let config = ModelConfiguration("GitVaultV2", schema: schema)
            let container = try ModelContainer(for: schema, configurations: [config])
            CrashReporter.logSync("container: rebuilt after removing broken store")
            return container
        } catch {
            CrashReporter.logSync("container: rebuild failed -> \(error)")
        }

        // 3) 内存兜底：宁可收藏不落盘，也不能一启动就闪退
        isUsingMemoryStore = true
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: schema, configurations: [memory]) {
            CrashReporter.logSync("container: using in-memory fallback")
            return container
        }

        // 到这里说明 SwiftData 本身不可用（极端情况），写入日志后给出明确崩溃点
        CrashReporter.logSync("container: FATAL - in-memory container unavailable")
        fatalError("GitVault: 无法初始化 SwiftData 容器，请查看诊断日志")
    }

    private static func removeStoreFiles() {
        let base = URL.applicationSupportDirectory
        let candidates = [
            base.appending(path: "GitVaultV2.store"),
            base.appending(path: "GitVaultV2.store-wal"),
            base.appending(path: "GitVaultV2.store-shm")
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            // 先备份再删，方便用户事后找回
            let backup = url.deletingLastPathComponent()
                .appending(path: url.lastPathComponent + ".bak-\(Int(Date().timeIntervalSince1970))")
            do {
                try FileManager.default.moveItem(at: url, to: backup)
                CrashReporter.logSync("container: backed up \(url.lastPathComponent)")
            } catch {
                try? FileManager.default.removeItem(at: url)
                CrashReporter.logSync("container: removed \(url.lastPathComponent)")
            }
        }
    }
}
