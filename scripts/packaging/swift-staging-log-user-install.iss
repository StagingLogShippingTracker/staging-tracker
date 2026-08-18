; Non-admin per-user installer for Swift Staging & Shipping Log
; Captions use && so Setup shows a single &. Folder / shortcut names use a
; single & (they are not caption fields — && would appear as two ampersands).
#define MyAppName "Swift Staging && Shipping Log"
#define MyAppShortcutName "Swift Staging & Shipping Log"
#define MyAppVersion "1.1.40"
#define MyAppPublisher "Swift Supply"
#define MyAppExeName "SwiftStagingLog.exe"

[Setup]
AppId={{A7C3E9B2-4F11-4D88-9C2A-51A7B6E41D20}}
AppName={#MyAppName}
AppVerName={#MyAppName} {#MyAppVersion}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\Swift Staging Shipping Log
DefaultGroupName={#MyAppShortcutName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\..\dist
OutputBaseFilename=SwiftStagingLog-Setup-User
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppShortcutName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{userdesktop}\{#MyAppShortcutName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
