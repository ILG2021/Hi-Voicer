import { describe, expect, it } from "vitest";
import { modelPresets } from "../data/modelPresets";

describe("offline model presets", () => {
  it("exposes the bundled offline models", () => {
    expect(modelPresets.map((model) => model.id)).toEqual([
      "sensevoice-small",
      "sherpa-paraformer-zh",
      "qwen3-asr-0.6b",
    ]);
  });

  it("does not contain runtime download URLs or install recipes", () => {
    for (const model of modelPresets) {
      expect(model.engineNote).toContain("随安装包提供");
      expect(model).not.toHaveProperty("downloadUrl");
      expect(model).not.toHaveProperty("modelFiles");
      expect(model).not.toHaveProperty("installKind");
    }
  });

  it("only exposes realtime-compatible models for voice input", () => {
    expect(modelPresets.filter((model) => model.roles.includes("input")).map((model) => model.id)).toEqual([
      "sensevoice-small",
    ]);
    expect(modelPresets.filter((model) => model.roles.includes("transcription")).map((model) => model.id)).toEqual([
      "sensevoice-small",
      "sherpa-paraformer-zh",
      "qwen3-asr-0.6b",
    ]);
  });
});
