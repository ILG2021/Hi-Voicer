# Hi-Voicer 1.2.1 发布说明

## 发布重点

- Qwen3-ASR 0.6B 改用官方 INT8 ONNX 模型并统一由 Sherpa-ONNX CPU 推理，用于准确率优先的文件转录。
- 新增基于 Silero VAD 的麦克风实时分句；每句结束后立即识别并输出，文件转录流程保持不变。
- 模型下载支持断点续传、文件大小检查和 SHA-256 校验；模型目录可以完整复制到其他电脑。
- 安装包内置 Sherpa-ONNX CPU 运行时、Silero VAD、FFmpeg 和 FFprobe，不包含旧 ASR 后端、CUDA、cuDNN、TensorRT 或 Vulkan 运行文件。
- 修复 GitHub Actions 对新版 FFmpeg 体积估算过低导致的发布阻断；应用功能与 1.2.0 候选版本一致。

## 发布验证

- 前端测试：72 项通过。
- Rust 发布配置测试：105 项通过。
- SenseVoice 与 Qwen3-ASR 统一使用 Sherpa-ONNX；发布前仍需在 Windows 真机完成实时麦克风回归验证。
- 正式 NSIS 与 MSI 安装包由 GitHub Actions 从 `v1.2.1` 标签构建，并生成 provenance attestation。

## 已知限制

- Qwen3-ASR INT8 官方归档约 838 MiB，由离线资源准备脚本下载并校验。
- 正式安装包仅包含 Sherpa-ONNX CPU 推理路线，不包含 GPU 运行时。
