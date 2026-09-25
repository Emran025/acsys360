#ifndef AppVersion
  #define AppVersion "0.0.3"
#endif
#ifndef SourceDir
  #define SourceDir "build/windows/x64/runner/Release"
#endif
#ifndef OutputDir
  #define OutputDir "dist"
#endif

[Setup]
AppId={{A36044B1-6F0A-4AC5-9360-000000000003}
AppName=acsys360
AppVersion={#AppVersion}
AppPublisher=acsys360
DefaultDirName={autopf}\acsys360
DefaultGroupName=acsys360
UninstallDisplayIcon={app}\acsys360.exe
OutputDir={#OutputDir}
OutputBaseFilename=acsys360-windows-{#AppVersion}-setup-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\acsys360"; Filename: "{app}\acsys360.exe"
Name: "{autodesktop}\acsys360"; Filename: "{app}\acsys360.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\acsys360.exe"; Description: "Launch acsys360"; Flags: postinstall nowait skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\toolchain"
