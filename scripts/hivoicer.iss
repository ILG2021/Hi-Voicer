; ============================================================
;  Hi-Voicer  --  Inno Setup script
;  Called from scripts/build-variants.ps1 via ISCC.exe
;
;  Required /D defines:
;    AppVariantSuffix   "" for CPU, " CUDA" for CUDA
;    AppVersion         e.g. "1.2.1"
;
;  SourceRoot is auto-computed from this file's location via SourcePath.
; ============================================================

#ifndef AppVariantSuffix
  #define AppVariantSuffix ""
#endif
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

; Compute repo root from this script's own location:
;   hivoicer.iss lives in  <repo>/scripts/
;   SourcePath           =  <repo>/scripts/    (ISPP built-in, with trailing backslash)
;   RemoveBackslash(...)  =>  <repo>/scripts
;   ExtractFilePath(...)  =>  <repo>/           (with trailing backslash)
;   RemoveBackslash(...)  =>  <repo>
#define SourceRoot RemoveBackslash(ExtractFilePath(RemoveBackslash(SourcePath)))

#define AppNameBase  "Hi-Voicer"
#define AppNameFull  AppNameBase + AppVariantSuffix
#define AppExeName   "hi-voicer.exe"

; Separate AppId ensures CPU and CUDA can coexist on the same machine
#if AppVariantSuffix == " CUDA"
  #define AppId "{A8F3C912-4B2E-4D1A-9C7F-BE2341056789}_CUDA"
#else
  #define AppId "{A8F3C912-4B2E-4D1A-9C7F-BE2341056789}_CPU"
#endif

[Setup]
AppId={#AppId}
AppName={#AppNameFull}
AppVersion={#AppVersion}
AppPublisher=Hi-Voicer
AppPublisherURL=https://github.com/ILG2021/Hi-Voicer
DefaultDirName={localappdata}\Programs\{#AppNameFull}
DefaultGroupName={#AppNameFull}
; No admin required -- per-user install
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
; Output
OutputDir={#SourceRoot}\dist-builds
OutputBaseFilename={#AppNameFull}_{#AppVersion}_x64-setup
; Compression
Compression=lzma2/ultra64
SolidCompression=yes
; Windows x64 only
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
; Cosmetics
SetupIconFile={#SourceRoot}\src-tauri\icons\icon.ico
UninstallDisplayName={#AppNameFull}
UninstallDisplayIcon={app}\{#AppExeName}
WizardStyle=modern
MinVersion=10.0.17763

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
; ---- Main executable ----
Source: "{#SourceRoot}\src-tauri\target\release\{#AppExeName}"; \
  DestDir: "{app}"; Flags: ignoreversion

; ---- Resources (flat -- matches Tauri's "resources/": "" bundle config) ----
; Everything inside src-tauri/resources/ is placed directly in {app},
; so Tauri's resource_dir() (= exe directory) resolves paths correctly.
Source: "{#SourceRoot}\src-tauri\resources\*"; \
  DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppNameFull}";               Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppNameFull}";     Filename: "{uninstallexe}"
Name: "{userdesktop}\{#AppNameFull}";         Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; Offer to launch app after install
Filename: "{app}\{#AppExeName}"; \
  Description: "Launch {#AppNameFull}"; \
  Flags: nowait postinstall skipifsilent

