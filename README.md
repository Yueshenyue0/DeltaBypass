# Delta Bypass

Kotlin + Jetpack Compose + MIUIX (HyperOS 风格) + GitHub Actions 自动构建的 Android 应用。

## 功能

- 底部 Tab：`bypass` / `作者`
- bypass 页：标题 Delta Bypass，输入框（校验链接必须以 `https://auth.platorelay.com/a?d=` 开头，否则提示"链接错误"），"绕过"按钮
- 点击绕过后输出框按步骤显示：收到链接 → 正在绕过captcha...（约12~20秒）→ 绕过成功，正在获取key → key获取成功，全程约15~30秒，每步间隔1~2秒
- 概率（15%）弹出失败："绕过失败，请重试"
- 成功生成 `FREE_` + 32 位 hex 随机 key；输出框动画缩小，下方弹出 key 卡片 + 复制按钮
- 作者页：显示 Eri

## 构建（GitHub Actions）

推送到 `main` 分支或手动触发 workflow：

GitHub → Actions → Android Build → Artifacts → 下载

- `android-release-apk`：`app/build/outputs/apk/release/app-release.apk`（debug 签名，可直接安装）
- `android-debug-apk`：`app/build/outputs/apk/debug/app-debug.apk`

## 版本组合（与 miuix 官方 example 一致）

| 组件 | 版本 |
| --- | --- |
| Gradle | 9.7.1 |
| AGP | 9.4.1 |
| Kotlin | 2.4.20 |
| Compose Compiler | Kotlin 插件 `org.jetbrains.kotlin.plugin.compose` 2.4.20 |
| MIUIX | 0.9.4 |
| activity-compose | 1.13.0 |
| JDK | 17 |
| compileSdk / targetSdk | 36 |
| minSdk | 29 |

## 依赖

| 库 | 版本 | 坐标 | 用途 |
| --- | --- | --- | --- |
| MIUIX UI | 0.9.4 | `top.yukonga.miuix.kmp:miuix-ui-android` | HyperOS 风格组件（用户指定） |
| MIUIX Icons | 0.9.4 | `top.yukonga.miuix.kmp:miuix-icons-android` | NavigationBarItem / 页面图标 |
| activity-compose | 1.13.0 | `androidx.activity:activity-compose` | ComponentActivity + setContent |

无网络请求（绕过流程为本地模拟动画），无需 INTERNET 权限。
