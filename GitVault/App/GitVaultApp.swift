//
//  GitVaultApp.swift
//  GitVault
//
//  应用入口。iOS 16 兼容版本：
//  - 不再依赖 SwiftData（iOS 17+），收藏走 VaultStore 的 JSON 持久化
//  - 启动只做两件事：装模拟器/真机取证、构建内存对象图，任何一步失败都不会崩
//

import SwiftUI

@main
struct GitVaultApp: App {
    @AppStorage(AppPrefs.appearance) private var appearanceRaw: String = AppearanceMode.dark.rawValue

    @StateObject private var environment: AppEnvironment
    @StateObject private var vault: VaultStore

    init() {
        CrashReporter.install()
        CrashReporter.logSync("app init: building object graph")
        let env = AppEnvironment.live()
        _environment = StateObject(wrappedValue: env)
        _vault = StateObject(wrappedValue: VaultStore())
        CrashReporter.logSync("app init: ready")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .environmentObject(environment.auth)
                .environmentObject(vault)
                .preferredColorScheme(
                    (AppearanceMode(rawValue: appearanceRaw) ?? .dark).colorScheme
                )
                .tint(DS.accent)
                .onAppear {
                    CrashReporter.log("root view appeared")
                }
        }
    }
}
