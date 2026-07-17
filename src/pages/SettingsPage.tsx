import { Check, Cpu, FolderOpen, Gauge, Keyboard, Mic, MonitorSpeaker, Moon, Sun, Volume2 } from "lucide-react";
import type { KeyboardEvent } from "react";
import { useRef, useState } from "react";
import { SettingRow } from "../components/SettingRow";
import { modelPresets } from "../data/modelPresets";
import { resolveBundledModelDir, selectDirectory } from "../lib/api";
import type { ThemeMode, UserSettings } from "../types";

type ModelRole = "input" | "transcription";

interface SettingsPageProps {
  settings: UserSettings;
  onOpenRecordingsFolder: () => void;
  onSettingsChange: (settings: UserSettings) => void;
}

function formatShortcut(event: KeyboardEvent<HTMLButtonElement>) {
  const parts: string[] = [];

  if (event.ctrlKey) {
    parts.push("Ctrl");
  }

  if (event.altKey) {
    parts.push("Alt");
  }

  if (event.shiftKey) {
    parts.push("Shift");
  }

  if (event.metaKey) {
    parts.push("Win");
  }

  const keyMap: Record<string, string> = {
    " ": "Space",
    Escape: "Esc",
    ArrowUp: "Up",
    ArrowDown: "Down",
    ArrowLeft: "Left",
    ArrowRight: "Right",
  };
  const key = keyMap[event.key] ?? event.key;

  if (!["Control", "Alt", "Shift", "Meta"].includes(event.key)) {
    parts.push(key.length === 1 ? key.toUpperCase() : key);
  }

  return parts.join("+");
}

export function SettingsPage({ settings, onOpenRecordingsFolder, onSettingsChange }: SettingsPageProps) {
  const [isCapturingShortcut, setIsCapturingShortcut] = useState(false);
  const [modelMessage, setModelMessage] = useState("");
  const [activeModelRole, setActiveModelRole] = useState<ModelRole>("input");
  const shortcutButtonRef = useRef<HTMLButtonElement>(null);
  const activeModelId =
    activeModelRole === "input"
      ? settings.inputModelId || settings.selectedModelId
      : settings.transcriptionModelId || settings.selectedModelId;
  const activeModelDir =
    activeModelRole === "input"
      ? settings.inputModelDir || settings.modelDir
      : settings.transcriptionModelDir || settings.modelDir;
  const availableModels = modelPresets.filter((model) => model.roles.includes(activeModelRole));
  const selectedModel = availableModels.find((model) => model.id === activeModelId) ?? availableModels[0];

  async function handleSelectModelDir() {
    try {
      setModelMessage("");
      const selected = await selectDirectory();
      if (selected) {
        onSettingsChange(
          activeModelRole === "input"
            ? { ...settings, modelDir: selected, inputModelDir: selected }
            : { ...settings, modelDir: selected, transcriptionModelDir: selected },
        );
        setModelMessage("模型目录已保存。");
      } else {
        setModelMessage("没有选择目录。");
      }
    } catch (error) {
      setModelMessage(error instanceof Error ? error.message : "打开目录选择失败。");
    }
  }

  function updateTheme(theme: ThemeMode) {
    onSettingsChange({ ...settings, theme });
  }

  async function selectModelForActiveRole(modelId: string) {
    try {
      const modelDir = await resolveBundledModelDir(modelId);
      onSettingsChange(
        activeModelRole === "input"
          ? { ...settings, selectedModelId: modelId, modelDir, inputModelId: modelId, inputModelDir: modelDir }
          : {
              ...settings,
              selectedModelId: modelId,
              modelDir,
              transcriptionModelId: modelId,
              transcriptionModelDir: modelDir,
            },
      );
      setModelMessage("已切换到安装包内置模型。");
    } catch (error) {
      setModelMessage(error instanceof Error ? error.message : "内置模型不可用。");
    }
  }

  function syncSelectedModelToBoth() {
    if (!selectedModel.roles.includes("input") || !selectedModel.roles.includes("transcription")) {
      setModelMessage(`${selectedModel.name} 不支持语音输入，不能同步到两处。`);
      return;
    }
    onSettingsChange({
      ...settings,
      selectedModelId: selectedModel.id,
      modelDir: activeModelDir,
      inputModelId: selectedModel.id,
      inputModelDir: activeModelDir,
      transcriptionModelId: selectedModel.id,
      transcriptionModelDir: activeModelDir,
    });
    setModelMessage("已同步到语音输入和文件转录。");
  }

  return (
    <section className="panel settings-panel">
      <p className="section-label">设置</p>

      <SettingRow label="界面皮肤" description="暗色不是纯黑，适合夜间长时间使用。">
        <div className="segmented-control" role="group" aria-label="界面皮肤">
          <button
            className={settings.theme === "light" ? "segment-button segment-button--active" : "segment-button"}
            type="button"
            onClick={() => updateTheme("light")}
          >
            <Sun size={16} />
            亮色
          </button>
          <button
            className={settings.theme === "dark" ? "segment-button segment-button--active" : "segment-button"}
            type="button"
            onClick={() => updateTheme("dark")}
          >
            <Moon size={16} />
            暗色
          </button>
        </div>
      </SettingRow>

      <SettingRow label="快捷键" description="点击右侧按钮后，直接按键盘上的按键或组合键。">
        <button
          ref={shortcutButtonRef}
          className={`shortcut-capture ${isCapturingShortcut ? "shortcut-capture--active" : ""}`}
          type="button"
          onClick={() => {
            setIsCapturingShortcut(true);
            shortcutButtonRef.current?.focus();
          }}
          onBlur={() => setIsCapturingShortcut(false)}
          onKeyDown={(event) => {
            event.preventDefault();
            const nextShortcut = formatShortcut(event);
            if (nextShortcut) {
              onSettingsChange({ ...settings, shortcut: nextShortcut });
              setIsCapturingShortcut(false);
            }
          }}
        >
          <Keyboard size={18} />
          {isCapturingShortcut ? "请按键..." : settings.shortcut}
        </button>
      </SettingRow>

      <SettingRow label="录制来源" description="麦克风适合语音输入；系统声音适合会议、网课和播放器；双来源会优先保存双轨。">
        <div className="segmented-control segmented-control--three" role="group" aria-label="录制来源">
          <button
            className={settings.recordingSource === "microphone" ? "segment-button segment-button--active" : "segment-button"}
            type="button"
            onClick={() => onSettingsChange({ ...settings, recordingSource: "microphone" })}
          >
            <Mic size={16} />
            麦克风
          </button>
          <button
            className={settings.recordingSource === "system" ? "segment-button segment-button--active" : "segment-button"}
            type="button"
            onClick={() => onSettingsChange({ ...settings, recordingSource: "system" })}
          >
            <Volume2 size={16} />
            系统声
          </button>
          <button
            className={settings.recordingSource === "microphoneAndSystem" ? "segment-button segment-button--active" : "segment-button"}
            type="button"
            onClick={() => onSettingsChange({ ...settings, recordingSource: "microphoneAndSystem" })}
          >
            <MonitorSpeaker size={16} />
            双来源
          </button>
        </div>
      </SettingRow>

      <SettingRow label="识别加速" description="0.2.0 正式版使用 CPU 稳定路线；GPU 后续作为实验后端单独验证。">
        <div className="segmented-control" role="group" aria-label="识别加速">
          <button
            className={settings.accelerationMode === "cpu" ? "segment-button segment-button--active" : "segment-button"}
            type="button"
            onClick={() => onSettingsChange({ ...settings, accelerationMode: "cpu" })}
          >
            <Cpu size={16} />
            CPU
          </button>
          <button
            className={settings.accelerationMode === "directml" ? "segment-button segment-button--active" : "segment-button"}
            type="button"
            onClick={() => onSettingsChange({ ...settings, accelerationMode: "directml" })}
          >
            <Gauge size={16} />
            {settings.directmlVerified ? "DirectML（已验证）" : "DirectML（实验）"}
          </button>

        </div>
        {settings.directmlVerified && settings.directmlVerifiedAt && (
          <span className="setting-hint">本机验证时间：{new Date(settings.directmlVerifiedAt).toLocaleString()}</span>
        )}
      </SettingRow>

      <div className="setting-row setting-row--stacked">
        <div className="setting-heading">
          <div>
            <strong>离线模型</strong>
            <p>默认模型已包含在安装包中，选择后直接在本机运行，不会发起公网下载。</p>
          </div>
          <button className="secondary-button" type="button" onClick={handleSelectModelDir}>
            <FolderOpen size={17} />
            选择已有模型目录
          </button>
        </div>

        <div className="segmented-control" role="group" aria-label="模型用途">
          <button
            className={activeModelRole === "input" ? "segment-button segment-button--active" : "segment-button"}
            type="button"
            onClick={() => setActiveModelRole("input")}
          >
            <Mic size={16} />
            语音输入
          </button>
          <button
            className={activeModelRole === "transcription" ? "segment-button segment-button--active" : "segment-button"}
            type="button"
            onClick={() => setActiveModelRole("transcription")}
          >
            <Volume2 size={16} />
            文件转录
          </button>
          <button className="segment-button" type="button" onClick={syncSelectedModelToBoth}>
            <Check size={16} />
            同步到两处
          </button>
        </div>

        <div className="model-grid">
          {availableModels.map((model) => {
            const isSelected = model.id === selectedModel.id;

            return (
              <button
                className={`model-card ${isSelected ? "model-card--selected" : ""}`}
                key={model.id}
                type="button"
                onClick={() => void selectModelForActiveRole(model.id)}
              >
                <span className="model-card__title">
                  {model.name}
                  {isSelected && <Check size={17} />}
                </span>
                <span>
                  {model.size} / {model.quality}
                </span>
                <span>{model.memory}</span>
                <small>{model.recommendedFor}</small>
                <em>随安装包提供，无需联网</em>
              </button>
            );
          })}
        </div>

        <div className="model-actions">
          <div>
            <span>当前模型目录</span>
            <strong>{settings.modelDir || "尚未选择"}</strong>
          </div>
        </div>
        <p className="model-message">
          当前用途：{activeModelRole === "input" ? "语音输入" : "文件转录"} / 目录：{activeModelDir || "未选择"}
        </p>
        {modelMessage && <p className="model-message">{modelMessage}</p>}
      </div>

      <SettingRow label="录音文件夹" description="纯录音模式和保留录音片段都会保存到这里。">
        <button className="path-button" type="button" onClick={onOpenRecordingsFolder}>
          <FolderOpen size={17} />
          <span>打开录音文件夹</span>
        </button>
      </SettingRow>

      <SettingRow label="保留识别录音" description="开启后会保留每次识别前的录音片段，便于排查识别问题。">
        <input
          aria-label="保留识别录音"
          type="checkbox"
          checked={settings.saveRecordings}
          onChange={(event) => onSettingsChange({ ...settings, saveRecordings: event.target.checked })}
        />
      </SettingRow>

      <SettingRow label="开机启动" description="开启后登录 Windows 自动启动，并安静驻留在托盘。">
        <input
          aria-label="开机启动"
          type="checkbox"
          checked={settings.launchAtStartup}
          onChange={(event) => onSettingsChange({ ...settings, launchAtStartup: event.target.checked })}
        />
      </SettingRow>

      <SettingRow label="显示悬浮按钮" description="开启后显示一个置顶 mini 录制按钮；关闭后只保留主窗口和快捷键。">
        <input
          aria-label="显示悬浮按钮"
          type="checkbox"
          checked={settings.showMiniWindow}
          onChange={(event) => onSettingsChange({ ...settings, showMiniWindow: event.target.checked })}
        />
      </SettingRow>
    </section>
  );
}
