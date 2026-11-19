//
//  GitVaultApp.swift
//  GitVault
//
//  应用入口：注入 SwiftData 容器 + 全局外观偏好。
//

import SwiftUI
import SwiftData

@main
struct GitVaultApp: App {
    /// 外观偏好（深色为默认）
    @AppStorage(AppPrefs.appearance) private var appearanceRaw: String = AppearanceMode.dark.rawValue

    /// SwiftData 容器：阶段 2 会补充更多实体与迁移策略
    private let container: ModelContainer = {
        let schema = Schema([VaultEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 极端情况下（磁盘损坏）退化为内存容器，保证 App 仍可启动
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(
                    (AppearanceMode(rawValue: appearanceRaw) ?? .dark).colorScheme
                )
                .tint(DS.accent)
        }
        .modelContainer(container)
    }
}
