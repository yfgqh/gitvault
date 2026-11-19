//
//  Keychain.swift
//  GitVault
//
//  Token 只进 Keychain，不落 UserDefaults、不写日志、不进代码。
//  读取路径全部做了防御：设备锁定 / entitlement 异常时返回 nil，绝不 crash。
//

import Foundation
import Security

enum Keychain {
    static let tokenKey = "gv.github.token"

    enum Error: Swift.Error {
        case unexpectedStatus(OSStatus)
    }

    private static var service: String {
        Bundle.main.bundleIdentifier ?? "com.yfgqh.gitvault"
    }

    /// 写入/更新
    @discardableResult
    static func save(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8), !value.isEmpty else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else {
            CrashReporter.log("keychain update failed status=\(status)")
            return false
        }

        var insert = query
        insert.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        if addStatus != errSecSuccess {
            CrashReporter.log("keychain add failed status=\(addStatus)")
        }
        return addStatus == errSecSuccess
    }

    /// 读取（任何异常都返回 nil：设备锁定、无 entitlement、条目损坏都不影响启动）
    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound, errSecInteractionNotAllowed, errSecNotAvailable, errSecAuthFailed:
            return nil
        default:
            CrashReporter.log("keychain read status=\(status) for \(key)")
            return nil
        }
    }

    /// 删除
    @discardableResult
    static func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
