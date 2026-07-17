import { describe, expect, it } from "vitest";
import { modelPresets } from "../data/modelPresets";

describe("offline model presets", () => {
  it("exposes only the two models bundled with the installer", () => {
    expect(modelPresets.map((model) => model.id)).toEqual([
      "sensevoice-small",
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
    expect(modelPresets.find((model) => model.id === "qwen3-asr-0.6b")?.roles).toEqual(["transcription"]);
  });
});
