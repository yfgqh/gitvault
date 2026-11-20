//
//  ProStore.swift
//  GitVault
//
//  Pro 解锁（StoreKit 2，一次性买断 ¥9.9，唯一档位）。
//  - 非消耗型内购：com.yfgqh.gitvault.pro
//  - 7 天全功能试用
//  - 免费额度：AI 翻译每日 5 次；Pro 无限
//  - 无 App Store 环境时降级为「试用 + 本地额度」，不崩不阻塞
//

import Foundation
import StoreKit
import Combine

@MainActor
final class ProStore: ObservableObject {
    static let productID = "com.yfgqh.gitvault.pro"
    static let fallbackPrice = "¥9.9"
    static let trialDays = 365
    static let freeAIDaily = 5

    @Published private(set) var product: Product?
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false
    @Published var message: String?

    private let trialStartKey = "gv.pro.trialStart"
    private let aiUsageKey = "gv.pro.aiUsage"

    // MARK: 价格展示

    var priceText: String {
        product?.displayPrice ?? ProStore.fallbackPrice
    }

    var productAvailable: Bool { product != nil }

    // MARK: 试用

    var trialStartDate: Date? {
        let stamp = UserDefaults.standard.double(forKey: trialStartKey)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    /// 首次启动即开始计时
    func markTrialIfNeeded() {
        guard UserDefaults.standard.double(forKey: trialStartKey) == 0 else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: trialStartKey)
    }

    var trialDaysLeft: Int {
        guard let start = trialStartDate else { return ProStore.trialDays }
        let used = Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0
        return max(0, ProStore.trialDays - used)
    }

    var trialActive: Bool { !isPro && trialDaysLeft > 0 }

    /// 完整功能可用（Pro 或试用期内）
    var hasFullAccess: Bool { isPro || trialActive }

    // MARK: AI 额度

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: .now)
    }

    var aiUsedToday: Int {
        let raw = UserDefaults.standard.string(forKey: aiUsageKey) ?? ""
        let parts = raw.split(separator: ":").map(String.init)
        guard parts.count == 2, parts[0] == todayKey, let count = Int(parts[1]) else { return 0 }
        return count
    }

    var aiQuotaLeft: Int {
        if hasFullAccess { return Int.max }
        return max(0, ProStore.freeAIDaily - aiUsedToday)
    }

    var canUseAI: Bool { hasFullAccess || aiQuotaLeft > 0 }

    /// 消耗一次额度；返回是否允许继续（Pro / 试用直接放行）
    @discardableResult
    func consumeAIQuota() -> Bool {
        if hasFullAccess { return true }
        let used = aiUsedToday
        guard used < ProStore.freeAIDaily else { return false }
        UserDefaults.standard.set("\(todayKey):\(used + 1)", forKey: aiUsageKey)
        return true
    }

    // MARK: 生命周期

    func bootstrap() async {
        markTrialIfNeeded()
        await loadProduct()
        await refreshEntitlements()
    }

    private func loadProduct() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [ProStore.productID])
            product = products.first
        } catch {
            // 没有 App Store 连接 / 未配置商品：不影响试用与本地功能
            product = nil
            CrashReporter.log("pro: load product failed \(error.localizedDescription)")
        }
    }

    func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == ProStore.productID, transaction.revocationDate == nil {
                isPro = true
                return
            }
        }
        isPro = false
    }

    // MARK: 购买 / 恢复

    func purchase() async {
        // 当前阶段限时免费：不发起真实交易，直接给出提示
        message = "目前无需购买（限时免费试用 365 天）"
        return
    }

    private func purchaseFromStore() async {
        guard let product else {
            message = "当前环境无法连接 App Store，请稍后重试"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = "购买校验未通过"
                    return
                }
                await transaction.finish()
                isPro = true
                message = "已解锁 Pro，感谢支持"
                Haptics.success()
            case .pending:
                message = "购买待确认，请稍后在「恢复购买」里检查"
            case .userCancelled:
                message = nil
            @unknown default:
                message = "购买未完成"
            }
        } catch {
            message = "购买失败：\(error.localizedDescription)"
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = isPro ? "已恢复 Pro 权益" : "没有找到可恢复的购买"
        } catch {
            message = "恢复失败：\(error.localizedDescription)"
        }
    }

    var statusTitle: String {
        if isPro { return "Pro 已解锁" }
        if trialActive { return "Pro 试用中 · 剩 \(trialDaysLeft) 天" }
        return "免费版"
    }
}
