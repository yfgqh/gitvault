# GitVault · GitHub 精选

> 帮助中文开发者整理、分类、追踪 GitHub 优质开源项目的 iOS App。
> 纯 SwiftUI + SwiftData，深色优先的原生高级感界面。

---

## 进度：阶段 1 – 5 全部完成 ✅

| 阶段 | 内容 | 状态 |
|---|---|---|
| 阶段 1 | 工程骨架 / DesignSystem / 悬浮 Tab Bar / Splash / 五个页面 / Mock 数据 | ✅ |
| 阶段 2 | DTO + GitHubService + Keychain + 规则分类器 + 中文摘要 + LLM 抽象层 + SwiftData 本地库 | ✅ |
| 阶段 3 | 首页 Explore + 分类页 + RepoCard + 详情页（Hero 转场 / 语言占比 / README 摘要） | ✅ |
| 阶段 4 | 搜索防抖 + 分页 + SwiftData 收藏 + 左滑操作 + 文件夹 + 环形统计 + 导出 | ✅ |
| 阶段 5 | Device Flow 登录 + 大模型配置 + iPad 分栏 + 动效 / 深色适配 / 无障碍 | ✅ |

## 功能清单

- **数据层**：`GitHubService`（REST v3，async/await，统一中文错误 + 自动重试 + 限流提示）
- **鉴权**：OAuth **Device Flow**（客户端不需要 secret），Token 存 **Keychain**
- **分类**：`RuleClassifier` 本地规则（topics / 语言 / 活跃度 / 许可）→ 6 大主题 + 四组标签
- **AI**：`LLMClassifierProtocol` 抽象，内置 OpenAI 兼容实现；未配置时规则兜底，离线可用
- **中文摘要**：优先中文 description，否则模板化中文句 + topic 中英映射；README 结构摘要
- **本地库**：SwiftData `VaultEntry` / `VaultFolder`，左滑标记、拖拽排序、JSON/Markdown 导出
- **交互**：spring 按压反馈、交错入场、爱心粒子、hero 转场、`.symbolEffect`、触觉反馈
- **适配**：深/浅色（深色默认）、Dynamic Type、VoiceOver 标签、iPhone + iPad 竖向轨道分栏

## 环境要求

- macOS 14+，Xcode 15.4 及以上（CI 实测 Xcode 26.x / iOS SDK 26.5 通过）
- 部署目标 **iOS 17.0**（`@Observable`、`.contentTransition`、`.symbolEffect`、
  `.scrollTargetBehavior(.paging)` 均为 iOS 17 API）
- 工程由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成，`.xcodeproj` 不入库

## 本地运行

```bash
brew install xcodegen
cd gitvault
xcodegen generate
open GitVault.xcodeproj
```

命令行编译（无签名）：

```bash
xcodebuild -project GitVault.xcodeproj -scheme GitVault \
  -sdk iphoneos -configuration Release \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

## 产出 IPA（无需 macOS 本机）

推送到 `main` 或手动触发 `Actions → iOS Build`：

1. `macos-latest` runner 选最新 Xcode；
2. `xcodegen generate` 生成工程；
3. `xcodebuild -configuration Release CODE_SIGNING_ALLOWED=NO` 编译；
4. 打包 `Payload/GitVault.app` → `GitVault-unsigned.ipa`（artifact）；
5. 同时上传 `GitVault.xcodeproj` 压缩包，本地无需装 XcodeGen。

> IPA 为**未签名**包。装真机需自行签名（Sideloadly / AltStore / 个人证书重签）；
> 也可解包后把 `.app` 拖进 iOS Simulator 直接运行。

## 目录结构

```
gitvault/
├── project.yml                      # XcodeGen 工程描述（唯一工程源）
├── GitVault/
│   ├── App/                         # 入口 / 根容器 / Splash / 依赖容器
│   ├── DesignSystem/                # 设计规范 + 复用组件（13 个）
│   ├── Models/                      # DTO / 分类 / 标签 / 展示模型 / SwiftData 实体
│   ├── Services/                    # GitHubService / AuthStore / VaultService / 分类器 / 摘要
│   ├── ViewModels/                  # Explore / CategoryFeed / Search / Detail
│   ├── Features/                    # Explore / Categories / Search / Vault / Profile / Detail
│   ├── Mock/                        # 离线示例数据
│   ├── Utils/                       # Keychain / 配置 / 错误 / 颜色 / 触觉 / 索引包装
│   └── Resources/Assets.xcassets    # AppIcon（脚本生成）+ AccentColor
├── Scripts/make_icon.js             # 1024px 图标生成器（纯 Node，零依赖）
└── .github/workflows/ios-build.yml  # macOS 编译 + 未签名 IPA
```

## 登录与 AI 配置

- **GitHub 登录**：在 GitHub → Settings → Developer settings → OAuth Apps 新建应用，
  勾选 **Enable Device Flow**，把 Client ID 填进「我的 → GitHub 登录」。
  App 走 Device Flow：展示验证码 → 浏览器授权 → 轮询换取 Token → 存 Keychain。
- **大模型**：「我的 → AI 摘要」填任意 OpenAI 兼容的 `chat/completions` 地址、模型名与 Key；
  Key 存 Keychain，请求直接发往你填写的地址。留空即使用本地规则。

## 设计规范速查

| 令牌 | 值 |
|---|---|
| bgPrimary | `#0B0E14` / `#FFFFFF` |
| bgSecondary | `#151A23` / `#F5F6FA` |
| accentGradient | `#6E7BFF → #A66CFF` |
| cardCorner / chipCorner / buttonCorner | 22 / 12 / 16 |
| spacing XS/S/M/L/XL | 4 / 8 / 16 / 24 / 32 |
| softShadow | black 8% · radius 20 · y 8 |
| springSnappy | `.spring(response: 0.4, dampingFraction: 0.7)` |

## 图标

`Scripts/make_icon.js` 纯 Node 生成 1024×1024 无透明 PNG，零依赖。
设计取向：借鉴 GitHub 的 **Octocat 猫耳**轮廓与 **fork 分支**语义，做成「保险库转盘」的二次创新 ——
猫耳圆环（vault）+ 中心三节点分支符号（Git），墨黑底 + 品牌紫蓝渐变。
改图标只需调脚本里的几何常量后 `node Scripts/make_icon.js` 重新生成。

## 崩溃排查（真机闪退）

1. **未签名 IPA 装真机会被系统直接 kill**：iOS 校验代码签名失败，表现就是点开即闪退。
   必须用 Sideloadly / AltStore / Xcode 个人证书重签后再装（见下文「安装到真机」）。
2. **App 内置启动取证**：`CrashReporter` 记录启动阶段埋点、未捕获异常和致命信号
   （SIGABRT/SIGSEGV/SIGBUS/SIGILL/SIGFPE/SIGTRAP），写入 `Documents/GitVault/diagnostics.log`，
   App 内「我的 → 诊断日志」可直接查看、复制、清空。
3. **本地库三级降级**：store 版本化为 `GitVaultV2.store`（不碰旧版本库），
   打不开 → 备份后重建 → 内存兜底，避免旧数据导致 `@Query` 崩溃。
4. **Keychain 全防御**：设备锁定、无 entitlement、条目损坏时统一返回 nil，不影响启动。

## 安装到真机

```bash
# 方式一：Xcode 直接跑（最稳，自带签名）
xcodegen generate && open GitVault.xcodeproj   # 选自己的 Team，Run

# 方式二：重签未签名 IPA（Sideloadly / AltStore）
# 把 GitVault-unsigned.ipa 拖进 Sideloadly，登录 Apple ID 重签后安装
```

## 数据来源

GitHub REST API v3（`search/repositories`、`repos/{owner}/{repo}`、`/languages`、`/readme`）。
未登录 60 次/小时，登录后 5000 次/小时。Token 仅存 Keychain，绝不硬编码。
本应用与 GitHub 官方无隶属关系。
