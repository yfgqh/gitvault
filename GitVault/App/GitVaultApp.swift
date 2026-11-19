//
//  GitVaultApp.swift
//  GitVault
//
//  应用入口：SwiftData 容器 + 依赖容器 + 全局外观偏好。
//

import SwiftUI
import SwiftData

@main
struct GitVaultApp: App {
    /// 外观偏好（深色为默认）
    @AppStorage(AppPrefs.appearance) private var appearanceRaw: String = AppearanceMode.dark.rawValue

    /// 依赖注入容器（网络 / 鉴权 / 大模型）
    @State private var environment = AppEnvironment()

    /// SwiftData 容器：收藏条目 + 用户文件夹
    private let container: ModelContainer = {
        let schema = Schema([VaultEntry.self, VaultFolder.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 极端情况下（磁盘损坏 / 架构不兼容）退化为内存容器，保证 App 仍可启动
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .preferredColorScheme(
                    (AppearanceMode(rawValue: appearanceRaw) ?? .dark).colorScheme
                )
                .tint(DS.accent)
        }
        .modelContainer(container)
    }
}
