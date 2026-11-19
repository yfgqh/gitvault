//
//  AuthStore.swift
//  GitVault
//
//  GitHub 登录：OAuth Device Flow（客户端无需 secret）。
//  iOS 16 兼容：ObservableObject + @Published。
//

import Foundation
import SwiftUI

@MainActor
final class AuthStore: ObservableObject {

    enum Status: Equatable {
        case idle
        case requesting
        case waiting
        case signedIn
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var user: GitHubUserDTO?
    @Published private(set) var userCode: String?
    @Published private(set) var verificationURL: URL?
    @Published private(set) var expiresAt: Date?
    @Published private(set) var hasToken: Bool = Keychain.read(Keychain.tokenKey)?.isEmpty == false

    private var deviceCode: String?
    private var pollTask: Task<Void, Never>?

    var isSignedIn: Bool { hasToken }
    var displayName: String { user?.name ?? user?.login ?? "未登录" }

    // MARK: 生命周期

    func restore() async {
        guard hasToken else { return }
        do {
            user = try await GitHubService.shared.currentUser()
            status = .signedIn
        } catch {
            if case GitHubError.unauthorized = error {
                signOut()
            } else {
                status = .idle
            }
        }
    }

    // MARK: Device Flow

    func start() async {
        let clientID = AppConfig.oauthClientID
        guard !clientID.isEmpty else {
            status = .failed("请先填写 GitHub OAuth App 的 Client ID（需勾选 Enable Device Flow）")
            return
        }

        status = .requesting
        do {
            let response = try await requestDeviceCode(clientID: clientID)
            deviceCode = response.deviceCode
            userCode = response.userCode
            verificationURL = URL(string: response.verificationURI)
            expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
            status = .waiting
            startPolling(clientID: clientID, interval: response.interval)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func cancel() {
        pollTask?.cancel()
        pollTask = nil
        deviceCode = nil
        userCode = nil
        status = .idle
    }

    func signOut() {
        pollTask?.cancel()
        pollTask = nil
        Keychain.delete(Keychain.tokenKey)
        hasToken = false
        user = nil
        userCode = nil
        deviceCode = nil
        status = .idle
    }

    // MARK: 私有

    private func startPolling(clientID: String, interval: Int) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            var wait = max(interval, 5)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(wait) * 1_000_000_000)
                if Task.isCancelled { return }

                do {
                    switch try await self.pollOnce(clientID: clientID) {
                    case .success(let token):
                        Keychain.save(token, for: Keychain.tokenKey)
                        self.hasToken = true
                        self.user = try? await GitHubService.shared.currentUser()
                        self.status = .signedIn
                        self.userCode = nil
                        Haptics.success()
                        return
                    case .pending:
                        continue
                    case .slowDown:
                        wait += 5
                        continue
                    case .expired:
                        self.status = .failed("验证码已过期，请重新发起登录")
                        return
                    case .denied:
                        self.status = .failed("已在 GitHub 侧取消授权")
                        return
                    }
                } catch {
                    self.status = .failed(error.localizedDescription)
                    return
                }
            }
        }
    }

    private enum PollResult {
        case success(String)
        case pending
        case slowDown
        case expired
        case denied
    }

    private func requestDeviceCode(clientID: String) async throws -> DeviceCodeResponse {
        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "scope", value: AppConfig.oauthScopes)
        ]
        return try await postForm(
            url: "https://github.com/login/device/code",
            form: body.percentEncodedQuery ?? "",
            as: DeviceCodeResponse.self
        )
    }

    private func pollOnce(clientID: String) async throws -> PollResult {
        guard let deviceCode else { return .expired }
        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "device_code", value: deviceCode),
            URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:device_code")
        ]
        let response = try await postForm(
            url: "https://github.com/login/oauth/access_token",
            form: body.percentEncodedQuery ?? "",
            as: AccessTokenResponse.self
        )
        if let token = response.accessToken, !token.isEmpty { return .success(token) }
        switch response.error {
        case "authorization_pending": return .pending
        case "slow_down": return .slowDown
        case "expired_token": return .expired
        case "access_denied": return .denied
        default: return .pending
        }
    }

    private func postForm<T: Decodable>(url: String, form: String, as type: T.Type) async throws -> T {
        guard let url = URL(string: url) else { throw GitHubError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("GitVault/1.2", forHTTPHeaderField: "User-Agent")
        request.httpBody = form.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GitHubError.transport("GitHub 登录接口不可用")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GitHubError.decoding("登录响应解析失败")
        }
    }
}
