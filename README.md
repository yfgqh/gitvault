# GitVault · GitHub 精选

> 帮助中文开发者整理、分类、追踪 GitHub 优质开源项目的 iOS App。
> 纯 SwiftUI + SwiftData，深色优先的原生高级感界面。

---

## 当前进度：阶段 1（项目骨架）✅

| 阶段 | 内容 | 状态 |
|---|---|---|
| 阶段 1 | 工程骨架 / DesignSystem / 悬浮 Tab Bar / Splash / 5 个页面可跑通 / Mock 数据 / 详情页外壳 | ✅ 完成 |
| 阶段 2 | Models 全量 + GitHubService + 本地缓存 + 规则分类器 | ⏳ 待开始 |
| 阶段 3 | 首页打磨 + 分类 + RepoCard + 详情页（Hero 转场 / README 摘要） | ⏳ 待开始 |
| 阶段 4 | 搜索联想 + SwiftData 收藏 + 左滑操作 + 环形统计 | ⏳ 待开始 |
| 阶段 5 | GitHub OAuth + LLM 分类抽象层 + 动效 / iPad / 本地化收尾 | ⏳ 待开始 |

---

## 环境要求

- macOS 14+，Xcode 15.4 及以上（已用 iOS 17 SDK 验证）
- 部署目标 **iOS 17.0**（原因：`@Observable`、`.contentTransition`、`.symbolEffect`、
  `.scrollTargetBehavior(.paging)` 等本设计指定能力均为 iOS 17 API）
- 工程文件由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成，
  `.xcodeproj` 不入库，避免多人协作时的工程文件冲突

> 若必须支持 iOS 16：把 `@Observable` 换成 `ObservableObject + @Published`，
> 并把 `.scrollTargetBehavior` / `.symbolEffect` 降级为等价实现即可，架构不变。

## 本地运行

```bash
# 1) 安装依赖工具（仅首次）
brew install xcodegen

# 2) 生成工程
cd gitvault
xcodegen generate

# 3) 打开并运行
open GitVault.xcodeproj

# 或直接用命令行编译（无签名，供 CI / 校验用）
xcodebuild -project GitVault.xcodeproj -scheme GitVault \
  -sdk iphoneos -configuration Debug \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

## 产出 IPA（无需 macOS 本机）

推送到 `main` 或手动触发 `Actions → iOS Build`，流水线会：

1. 在 `macos-14` runner 上选最新 Xcode；
2. `xcodegen generate` 生成工程；
3. `xcodebuild` 以 `CODE_SIGNING_ALLOWED=NO` 编译；
4. 打包 `Payload/GitVault.app` → `GitVault-unsigned.ipa` 作为 artifact 上传；
5. 同时上传生成好的 `GitVault.xcodeproj` 压缩包，本地无需安装 XcodeGen。

> 产出的 IPA 为**未签名**包。安装到真机需要自行签名（Sideloadly / AltStore / Xcode
> 个人证书重签）；未签名包也可解压后把 `.app` 拖入 iOS Simulator 直接运行。

## 目录结构

```
gitvault/
├── project.yml                     # XcodeGen 工程描述（唯一工程源）
├── GitVault/
│   ├── App/                        # 入口、根容器、启动页
│   ├── DesignSystem/               # 设计规范 + 复用组件
│   ├── Models/                     # 分类、标签、展示模型、SwiftData 实体
│   ├── Mock/                       # 阶段 1 Mock 数据
│   ├── Features/                   # Explore / Categories / Search / Vault / Profile / Detail
│   ├── Utils/                      # 颜色、触觉、外观偏好
│   └── Resources/Assets.xcassets   # AppIcon（脚本生成）+ AccentColor
├── Scripts/make_icon.js            # 1024px 图标生成器（纯 Node，无三方依赖）
└── .github/workflows/ios-build.yml # macOS 编译 + 未签名 IPA
```

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

## 数据来源

GitHub REST API v3（`search/repositories`、`repos/{owner}/{repo}`）。
未登录 60 次/小时，OAuth 登录后 5000 次/小时。Token 仅存 Keychain，绝不硬编码。

本应用与 GitHub 官方无隶属关系。
