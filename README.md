# Hi-Voicer

Hi-Voicer 是面向 Windows 的本地离线语音工作台。它把语音输入、音频/视频文件转写、字幕校对、术语替换和基础音频处理放在同一个桌面应用里完成；模型、录音、缓存和转写结果默认留在本机。

![Hi-Voicer 产品概览](docs/assets/hi-voicer-overview.svg)

## 适合谁

- 想用快捷键在任意输入框里说话并自动上屏的用户。
- 需要把会议、网课、录音、视频整理成文字或字幕的用户。
- 希望转写流程尽量离线、本地可控的用户。
- 需要批量处理音频、校正字幕片段、维护术语替换表的用户。

## 主要能力

- 语音输入：支持按住说话、连续识别、纯录音三种模式。
- 文件转写：支持音频和常见视频文件，导出纯文本、时间线文本和 SRT 字幕。
- 字幕编辑：校正文案、拆分/合并字幕、播放选中片段、导出选中片段音频。
- 术语库：把常见错词、专有名词和客户名统一替换。
- 音频处理：降噪、增强、格式转换、视频提取音频、波形剪辑、多段导出和音频合并。
- 本机诊断：检查模型、运行时、麦克风、系统声音和 ffmpeg 状态。

## 1.2.1 更新重点

- 推理引擎统一为 `sherpa-onnx` Rust crate（原生进程内推理），彻底移除 `sherpa-onnx-offline.exe` 子进程依赖。
- 模型支持：SenseVoice Small、Qwen3-ASR 0.6B（ONNX INT8）、Paraformer 系列（含 FunASR Nano）。
- 推理后端：CPU only（DirectML 保留为 SenseVoice 实验路径）。
- 实时语音输入使用 Silero VAD 实时切句，每段语音结束后立即离线识别并输入文字。
- Qwen3-ASR GGUF 格式通过 llama.cpp 服务进程支持（可选），ONNX 格式通过 sherpa-onnx native 支持。
- 模型目录支持动态发现，可整体复制给其他用户后自动重绑定路径。
- 新增模型一键下载安装（Settings 界面），首次运行后按需下载即可，无需离线安装包预置模型。
- CUDA、cuDNN 和 GPU 运行文件继续排除在正式安装包之外。

详见：[Hi-Voicer 1.2.1 发布说明](docs/release-1.2.1.md)

## 下载与安装

优先从 [secure-artifacts/Hi-Voicer Releases](https://github.com/secure-artifacts/Hi-Voicer/releases) 下载可信构建；个人仓库 [cg202601/Hi-Voicer Releases](https://github.com/cg202601/Hi-Voicer/releases) 同步发布相同版本：

- 推荐普通用户使用 `Hi-Voicer_1.2.1_x64-setup.exe`
- 也可以下载同版本 MSI 安装包

正式安装包已包含 FFmpeg 和全部 CPU 运行组件。首次运行后可在 Settings 界面一键下载所需 ASR 模型，也可手动指定已有模型目录。录音识别、文件转写和音频处理均在本机完成，安装后无需联网。

## 当前模型策略

推理架构：`sherpa-onnx` Rust crate 原生 in-process 推理（CPU），不调用外部 .exe。

支持的模型格式：

| 模型 | 格式 | 引擎 | 说明 |
|---|---|---|---|
| SenseVoice Small | ONNX INT8 | sherpa-onnx native | 默认推荐，适合语音输入和短音频 |
| Qwen3-ASR 0.6B | ONNX INT8 | sherpa-onnx native | 文件转录推荐，高精度 |
| Qwen3-ASR 0.6B | GGUF Q8 | llama.cpp 服务进程 | 备选格式，需额外下载 llama.cpp 运行时 |
| Paraformer / FunASR Nano | ONNX | sherpa-onnx native | 支持，自动识别 paraformer/funasr 目录 |

## 发布来源验证

正式安装包由 GitHub Actions 在 `v*` tag 推送后自动构建、生成 attestation 并上传到 Release。组织仓库是首选可信来源；不要使用来源不明的本地手工包。

```powershell
gh attestation verify .\Hi-Voicer_1.2.1_x64-setup.exe --repo secure-artifacts/Hi-Voicer
```

## 开发验证

```powershell
npm ci
npm run prepare:offline
npm run check:offline
npm test
npm run build
cargo test --manifest-path src-tauri\Cargo.toml
npm run package:offline
```

## 打包流程

### 前置条件（首次，只需做一次）

1. 安装 [Rust 工具链](https://rustup.rs/)（需要 `x86_64-pc-windows-msvc` target）
2. 安装 Node.js >= 20 和 npm
3. 安装 JS 依赖：

```powershell
npm install
```

4. 下载离线资源（FFmpeg 等，耗时较长）：

```powershell
npm run prepare:offline
```

该命令按顺序执行以下步骤，任一失败即中止：

| 步骤 | 脚本 | 说明 |
|---|---|---|
| ① 安全扫描 | `check-runtime-offline.ps1` | 确认运行时源码中不含任何公网 URL |
| ② FFmpeg | `prepare-ffmpeg-runtime.ps1` | 下载 FFmpeg 8.1.2，SHA256 校验后提取到 `resources/` |
| ③ 资源完整性检查 | `check-bundled-resources.ps1` | 验证必需文件存在、哈希正确、无 GPU 运行时混入 |

> **注**：ASR 模型不再随安装包内置，由用户在应用内按需一键下载。

### 构建安装包

离线资源就绪后执行：

```powershell
npm run tauri -- build
```

构建流程：

```
TypeScript 类型检查（tsc）
    ↓
前端编译（vite build）→ 压缩的 HTML/JS/CSS
    ↓
Rust 后端编译（cargo build --release）
    ↓
Tauri 打包 → Hi-Voicer_x.x.x_x64-setup.exe / .msi
```

### 一键完整打包（首次）

```powershell
npm install
npm run package:offline    # 等价于：npm run prepare:offline && npm run tauri -- build
```

### 日常重新打包（资源已就绪）

```powershell
npm run tauri -- build
```

更多说明见：

- [模型说明](docs/模型说明.md)
- [环境准备](docs/环境准备.md)
- [0.2.1 打包测试清单](docs/0.2.1-打包测试清单.md)
