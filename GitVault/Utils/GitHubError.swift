//
//  GitHubError.swift
//  GitVault
//
//  统一错误模型：所有网络错误最后都会变成一句中文提示 + 是否可重试。
//

import Foundation

enum GitHubError: LocalizedError, Equatable {
    case invalidURL
    case offline
    case timeout
    case unauthorized
    case forbidden
    case notFound
    case rateLimited(resetAt: Date?)
    case server(Int)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求地址不合法"
        case .offline:
            return "网络似乎断开了，检查一下 Wi-Fi 或蜂窝网络"
        case .timeout:
            return "请求超时了，稍后再试一次"
        case .unauthorized:
            return "Token 已失效，请重新登录 GitHub"
        case .forbidden:
            return "GitHub 拒绝了这次请求，可能触发了二次验证"
        case .notFound:
            return "这个仓库不存在，可能已被删除或改名"
        case .rateLimited(let resetAt):
            if let resetAt {
                let seconds = max(0, Int(resetAt.timeIntervalSinceNow))
                let minutes = max(1, seconds / 60)
                return "接口额度用完了，约 \(minutes) 分钟后恢复；登录 GitHub 可提到每小时 5000 次"
            }
            return "接口额度用完了，登录 GitHub 可提到每小时 5000 次"
        case .server(let code):
            return "GitHub 服务异常（HTTP \(code)），稍后再试"
        case .decoding:
            return "数据解析失败，可能是接口字段发生了变化"
        case .transport(let message):
            return "网络请求失败：\(message)"
        }
    }

    /// 是否值得自动重试。
    /// 注意：.transport 也包含「请求取消」，重试会让取消操作变慢甚至看起来卡死，故不重试。
    var isRetryable: Bool {
        switch self {
        case .timeout, .server:
            return true
        case .offline, .transport, .rateLimited, .unauthorized, .forbidden, .notFound, .decoding, .invalidURL:
            return false
        }
    }

    /// 由 HTTP 状态码映射
    static func from(statusCode: Int, resetAt: Date? = nil) -> GitHubError {
        switch statusCode {
        case 401: return .unauthorized
        case 403: return resetAt != nil ? .rateLimited(resetAt: resetAt) : .forbidden
        case 404: return .notFound
        case 429: return .rateLimited(resetAt: resetAt)
        case 500...599: return .server(statusCode)
        default: return .transport("HTTP \(statusCode)")
        }
    }
}
