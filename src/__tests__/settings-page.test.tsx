import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { initialSettings } from "../data/mockState";
import { SettingsPage } from "../pages/SettingsPage";

vi.mock("../lib/api", () => ({
  resolveBundledModelDir: vi.fn((modelId: string) =>
    Promise.resolve(`C:\\Program Files\\Hi-Voicer\\models\\${modelId}`),
  ),
  selectDirectory: vi.fn(() => Promise.resolve(null)),
}));

function renderSettings(onSettingsChange = vi.fn()) {
  const result = render(
    <SettingsPage
      settings={initialSettings}
      onOpenRecordingsFolder={vi.fn()}
      onSettingsChange={onSettingsChange}
    />,
  );
  return { ...result, onSettingsChange };
}

describe("SettingsPage", () => {
  it("captures keyboard shortcuts by pressing keys", () => {
    const { onSettingsChange } = renderSettings();
    const shortcutButton = screen.getByRole("button", { name: "CapsLock" });
    fireEvent.click(shortcutButton);
    fireEvent.keyDown(shortcutButton, { key: "K", ctrlKey: true, shiftKey: true });
    expect(onSettingsChange).toHaveBeenCalledWith(expect.objectContaining({ shortcut: "Ctrl+Shift+K" }));
  });

  it("does not offer the file-only Qwen model for realtime input", () => {
    renderSettings();
    expect(screen.queryByRole("button", { name: /Qwen3-ASR 0.6B/ })).toBeNull();
  });

  it("selects a separate bundled transcription model", async () => {
    const { container, onSettingsChange } = renderSettings();
    const modelRoleButtons = Array.from(container.querySelectorAll(".setting-row--stacked .segmented-control button"));
    fireEvent.click(modelRoleButtons[1]);
    fireEvent.click(screen.getByRole("button", { name: /SenseVoiceSmall/ }));
    await waitFor(() =>
      expect(onSettingsChange).toHaveBeenCalledWith(
        expect.objectContaining({
          transcriptionModelId: "sensevoice-small",
          transcriptionModelDir: expect.stringContaining("sensevoice-small"),
        }),
      ),
    );
  });

  it("offers the bundled Qwen model for file transcription", () => {
    const { container } = renderSettings();
    const modelRoleButtons = Array.from(container.querySelectorAll(".setting-row--stacked .segmented-control button"));
    fireEvent.click(modelRoleButtons[1]);
    expect(screen.getByRole("button", { name: /Qwen3-ASR 0.6B/ })).toBeInTheDocument();
  });

  it("selects dark theme", () => {
    const { container, onSettingsChange } = renderSettings();
    const themeButtons = Array.from(container.querySelectorAll(".setting-row:first-of-type button"));
    fireEvent.click(themeButtons[1]);
    expect(onSettingsChange).toHaveBeenCalledWith(expect.objectContaining({ theme: "dark" }));
  });

  it("offers only CPU acceleration", () => {
    const { onSettingsChange } = renderSettings();
    const cpuButton = screen.getByRole("button", { name: "CPU" });
    expect(screen.queryByRole("button", { name: /CUDA/i })).toBeNull();
    fireEvent.click(cpuButton);
    expect(onSettingsChange).toHaveBeenCalledWith(expect.objectContaining({ accelerationMode: "cpu" }));
  });

  it("toggles launch at startup", () => {
    const { onSettingsChange } = renderSettings();
    fireEvent.click(screen.getByLabelText("开机启动"));
    expect(onSettingsChange).toHaveBeenCalledWith(expect.objectContaining({ launchAtStartup: true }));
  });

  it("toggles mini window visibility", () => {
    const { onSettingsChange } = renderSettings();
    fireEvent.click(screen.getByLabelText("显示悬浮按钮"));
    expect(onSettingsChange).toHaveBeenCalledWith(expect.objectContaining({ showMiniWindow: false }));
  });
});
