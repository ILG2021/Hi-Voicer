# Hi-Voicer 1.2.0 发布说明

## 发布重点

- 新增 Qwen3-ASR 0.6B INT8 ONNX 版，由 Sherpa-ONNX CPU 推理，用于准确率优先的文件转录。
- 高效版按 60 秒切分长音频，复用常驻本地服务，并在空闲 5 分钟后自动释放内存。
- 模型下载支持断点续传、文件大小检查和 SHA-256 校验。
- Qwen、SenseVoice 和 Paraformer 模型目录可以整体复制到其他电脑；软件自动使用模型目录的实际位置。
- 安装包内置 Sherpa-ONNX CPU 运行时、FFmpeg 和 FFprobe；复制模型后不需要额外下载引擎。
- CUDA、cuDNN、TensorRT 和 Vulkan 运行文件不进入正式安装包。
- 全局快捷键被其他程序占用时不再导致应用启动崩溃，用户仍可进入设置修改快捷键。

## 模型分发

模型与安装包保持分离。可以把完整模型目录压缩后交给其他用户，接收方解压到 `%LOCALAPPDATA%\com.local.hivoicer\models`，或通过“选择已有模型目录”指定其他磁盘位置。

Qwen3-ASR ONNX 目录必须包含 `engine.json`、模型文件、`tokens.txt` 和完整 tokenizer 目录。Sherpa 模型均需要保留完整目录结构。

## 发布验证

- 前端测试：72 项通过。
- Rust 发布配置测试：105 项通过。
- Qwen3-ASR ONNX 与 SenseVoice 静态 CPU 识别完成真实运行验证。
- 资源检查：243.9 MiB，未发现 CUDA、cuDNN、TensorRT 或 Vulkan 文件。
- Windows NSIS 与 MSI 安装包本地构建成功；正式资产由 GitHub Actions 重新构建并生成 provenance attestation。

## 已知限制

- Qwen3-ASR INT8 ONNX 官方归档约 838 MiB，需要单独下载或复制。
- DirectML 需要在每台电脑上单独验证；正式安装包不包含 CUDA 运行时。
