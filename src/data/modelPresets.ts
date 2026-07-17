import type { ModelPreset } from "../types";

export const modelPresets: ModelPreset[] = [
  {
    id: "sensevoice-small",
    name: "SenseVoiceSmall 中文优先",
    family: "sherpa",
    roles: ["input", "transcription"],
    size: "约 240 MB",
    quality: "中文、粤语、英文稳定，低延迟",
    memory: "CPU 可运行",
    recommendedFor: "内置语音输入模型",
    license: "SenseVoice 模型许可",
    engineNote: "模型和 Sherpa-ONNX CPU 运行时均随安装包提供。",
  },
  {
    id: "qwen3-asr-0.6b",
    name: "Qwen3-ASR 0.6B 高效版",
    family: "qwen",
    roles: ["transcription"],
    size: "约 838 MiB",
    quality: "INT8 量化，文件转写质量优先",
    memory: "建议 8 GB 以上内存",
    recommendedFor: "内置文件转写模型",
    license: "Apache 2.0 / sherpa-onnx Apache 2.0",
    engineNote: "模型由 Sherpa-ONNX CPU 运行时推理，随离线安装包提供。",
  },
];

export function findModelPreset(modelId: string) {
  return modelPresets.find((model) => model.id === modelId);
}
