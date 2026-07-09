# Hi-Voicer 1.1.1 发布说明

## 发布重点

- Windows 发布包内置 FFmpeg release essentials 运行时中的 `ffmpeg.exe` 和 `ffprobe.exe`，普通用户不再需要手动安装 ffmpeg 或配置 PATH。
- 安装包不包含 `ffplay.exe`，减少体积；Hi-Voicer 当前音频剪辑预览不依赖 FFmpeg 的独立播放器。
- Tauri bundle 配置明确包含 `src-tauri/resources/`，本地打包和 GitHub Actions 发布包都会把运行时资源放入应用资源目录。
- GitHub Actions 发布流程会在构建前下载 Gyan FFmpeg release essentials ZIP，并只拷贝 `ffmpeg.exe` / `ffprobe.exe` 进入发布包。
- 补充第三方运行时声明，记录 FFmpeg、Gyan Windows builds 和 GPLv3 授权信息。

## 使用建议

- 普通用户优先下载 `Hi-Voicer_1.1.1_x64-setup.exe`。
- 如只做语音输入、文件转写、字幕片段导出、音频转码、剪辑、混音和波形生成，不需要额外配置 ffmpeg。
- 开发调试包如果没有运行发布 workflow，需要本地准备 `src-tauri/resources/engines/ffmpeg/bin/ffmpeg.exe` 和 `ffprobe.exe` 后再打包。

## 发布前验证

- `npm test`
- `npm run build`
- `cargo test --manifest-path src-tauri/Cargo.toml`
- `npm run tauri -- build`

## 已知限制

- GitHub Actions 使用构建时最新的 Gyan FFmpeg release essentials ZIP；如未来需要完全可复现的二进制版本，应改为固定版本 URL 和 SHA-256 校验。
- FFmpeg Windows builds 依据 GPLv3 授权提供；内部流转仍保留第三方声明和来源链接。