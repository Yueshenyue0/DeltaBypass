# Delta Bypass

Flutter + Material 3 (MD3) + GitHub Actions 自动构建的 Android 应用。

## 功能
- 标题 Delta Bypass，输入框校验链接必须以 `https://auth.platorelay.com/a?d=` 开头，否则提示「链接错误」
- 点「绕过」后终端风格输出栏依次显示日志（NET / TLS / discord账号池 / captcha / key），每步间隔随机 1~2.5 秒，全程约 15~30 秒
- 20% 概率在 captcha 后报「绕过失败，请重试」（429/403/401/504 随机原因）
- 成功生成 `FREE_` + 32 位小写 hex key，输出框缩小，弹出 key 卡片 + 复制按钮
- 本地 SharedPreferences 缓存：同一链接再次绕过时约 5 秒直接返回原 key

## UI 风格
- Material 3 暗色主题，青色霓虹主色调
- 输出栏：「输出：」标签 + 近黑背景 + 霓虹发光描边 + 彩色等宽字体（NET青/TLS紫/POOL绿/captcha黄/key绿/错误红）
- 底部霓虹进度条，完成态变红

## 构建（GitHub Actions）
推送到 `main` 或手动触发 workflow，产物：
- `delta-bypass-apk` → `build/app/outputs/flutter-apk/app-release.apk`

android/ 骨架由 CI 里 `flutter create .` 生成，仓库不提交 android 目录。

## 结构
```
project/
├── lib/
│   └── main.dart
├── pubspec.yaml
├── .github/
│   └── workflows/
│       └── build.yml
└── README.md
```
