import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { initialDiagnostics, initialSettings } from "../data/mockState";
import {
  getNativeAudioDiagnostics,
  runAccelerationSmokeTest,
  saveTextFile,
  selectAudioFiles,
  transcribeFile,
} from "../lib/api";
import { DiagnosticsPage } from "../pages/DiagnosticsPage";

vi.mock("../lib/api", () => ({
  getAccelerationStatus: vi.fn(() =>
    Promise.resolve({
      selectedMode: "cpu",
      effectiveMode: "cpu",
      cudaAvailable: false,
      cudaDeviceSummary: null,
      cudaDetectionError: null,
      cpuRuntimeInstalled: true,
      cudaRuntimeInstalled: false,
      cudaDisabledReason: null,
      message: "CPU selected",
    }),
  ),
  getNativeAudioDiagnostics: vi.fn(() =>
    Promise.resolve({
      microphoneAvailable: true,
      microphoneName: "USB Microphone",
      microphoneDetail: "48000 Hz / 1 channel(s) / F32",
      systemAudioAvailable: true,
      systemAudioName: "Speakers",
      systemAudioDetail:
        "48000 Hz / 2 channel(s) / F32. Output device detected; system-audio recording still depends on WASAPI loopback support and will be verified when recording starts.",
      ffmpegInstalled: false,
      ffmpegPath: null,
      ffmpegDetail:
        "ffmpeg.exe was not found. Place ffmpeg.exe under one of these folders, or add ffmpeg to PATH: C:\\Users\\tester\\AppData\\Local\\com.local.hivoicer\\engines\\ffmpeg | system PATH. Hi-Voicer will not download ffmpeg automatically.",
      message: "Native audio environment needs attention before all recording and processing modes are available.",
    }),
  ),
  runAccelerationSmokeTest: vi.fn(() =>
    Promise.resolve({
      requestedMode: "cpu",
      usedMode: "cpu",
      fallbackUsed: false,
      elapsedMs: 123,
      transcriptPreview: "",
      message: "CPU smoke test completed; silent audio does not need recognized text.",
    }),
  ),
  saveTextFile: vi.fn(() => Promise.resolve("C:\\reports\\diagnostics.txt")),
  selectAudioFiles: vi.fn(() => Promise.resolve(["C:\\audio\\sample.wav"])),
  transcribeFile: vi.fn((_audioPath: string, settings: { accelerationMode: string }) =>
    Promise.resolve({
      text: "recognized",
      outputPath: "",
      outputPaths: [],
      outputFiles: [],
      segments: [{ id: "1", index: 1, start: 0, end: 10, text: "recognized", sourceAudioPath: "C:\\audio\\sample.wav" }],
      timelineKind: "estimated",
      sourceAudioPath: "C:\\audio\\sample.wav",
      usedAccelerationMode: settings.accelerationMode,
      accelerationFallbackUsed: false,
    }),
  ),
}));

describe("DiagnosticsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("runs a model smoke test without saving transcript output", async () => {
    const { container } = render(<DiagnosticsPage items={initialDiagnostics} modelReady={true} settings={initialSettings} />);

    fireEvent.click(container.querySelector(".primary-button") as HTMLButtonElement);

    await waitFor(() => {
      expect(transcribeFile).toHaveBeenCalledWith("C:\\audio\\sample.wav", initialSettings, { saveOutput: false });
    });
    expect(selectAudioFiles).toHaveBeenCalledTimes(1);
    expect(await screen.findByText("recognized")).toBeTruthy();
  });

  it("shows the current acceleration runtime status", async () => {
    render(<DiagnosticsPage items={initialDiagnostics} modelReady={true} settings={initialSettings} />);

    expect(await screen.findByText("CPU selected")).toBeTruthy();
    expect(screen.getByText("cpu")).toBeTruthy();
    expect(screen.queryByText(/NVIDIA|CUDA/)).toBeNull();
  });

  it("shows native audio diagnostics and refreshes them", async () => {
    const { container } = render(<DiagnosticsPage items={initialDiagnostics} modelReady={true} settings={initialSettings} />);

    expect(await screen.findByText(/USB Microphone/)).toBeTruthy();
    expect(screen.getByText(/Speakers/)).toBeTruthy();
    expect(screen.getByText(/WASAPI loopback/)).toBeTruthy();
    expect(screen.getByText(/ffmpeg.exe was not found/)).toBeTruthy();
    expect(screen.getByText(/system PATH/)).toBeTruthy();

    const refreshButton = container.querySelectorAll(".diagnostic-tool .secondary-button")[0] as HTMLButtonElement;
    fireEvent.click(refreshButton);

    await waitFor(() => {
      expect(getNativeAudioDiagnostics).toHaveBeenCalledTimes(2);
    });
  });

  it("runs the CPU smoke test with the current settings", async () => {
    const settings = { ...initialSettings, modelDir: "C:\\models\\demo" };
    render(<DiagnosticsPage items={initialDiagnostics} modelReady={true} settings={settings} />);

    fireEvent.click(screen.getByRole("button", { name: /CPU smoke test/ }));

    await waitFor(() => {
      expect(runAccelerationSmokeTest).toHaveBeenCalledWith(settings);
    });
    expect(await screen.findByText(/CPU smoke test completed/)).toBeTruthy();
    expect(screen.getByText(/实际路径：CPU/)).toBeTruthy();
  });

  it("saves a diagnostic report with CPU runtime and native audio details", async () => {
    const settings = { ...initialSettings, modelDir: "C:\\models\\demo" };
    const { container } = render(<DiagnosticsPage items={initialDiagnostics} modelReady={true} settings={settings} />);

    fireEvent.click(screen.getByRole("button", { name: /CPU smoke test/ }));
    await screen.findByText(/CPU smoke test completed/);

    const buttons = container.querySelectorAll(".diagnostic-tool .secondary-button");
    fireEvent.click(buttons[buttons.length - 1] as HTMLButtonElement);

    await waitFor(() => {
      expect(saveTextFile).toHaveBeenCalledWith(
        expect.stringMatching(/^hi-voicer-diagnostics-.+\.txt$/),
        expect.stringContaining("Hi-Voicer"),
      );
    });
    expect(saveTextFile).toHaveBeenCalledWith(expect.any(String), expect.stringContaining("实际路径: cpu"));
    expect(saveTextFile).toHaveBeenCalledWith(expect.any(String), expect.stringContaining("USB Microphone"));
  });

});

