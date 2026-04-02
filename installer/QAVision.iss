#define MyAppName "QAVision"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "QAVision"
#define MyAppExeName "qavision.exe"
#define MyAppId "{{E0E5E1A8-2D57-4D73-8B13-6A647F5A9E21}"
#define MySourceDir "..\build\windows\x64\runner\Release"
#define MyIconFile "..\windows\runner\resources\app_icon.ico"
#define MyInstalledIconFile "{app}\\app_icon.ico"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/reySanchezDev/qaVision
AppSupportURL=https://github.com/reySanchezDev/qaVision
AppUpdatesURL=https://github.com/reySanchezDev/qaVision
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist\installer
OutputBaseFilename=QAVision-Setup-{#MyAppVersion}
SetupIconFile={#MyIconFile}
UninstallDisplayIcon={#MyInstalledIconFile}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
ChangesAssociations=no
ChangesEnvironment=no

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; Flags: unchecked

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyIconFile}"; DestDir: "{app}"; DestName: "app_icon.ico"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{#MyInstalledIconFile}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{#MyInstalledIconFile}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir {#MyAppName}"; Flags: nowait postinstall skipifsilent
