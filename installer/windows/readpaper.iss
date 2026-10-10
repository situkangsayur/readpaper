; Pemasang ReadPaper untuk Windows (Inno Setup 6).
;
; Dibangun di CI Windows: ISCC.exe /DMyAppVersion=<versi> installer\windows\readpaper.iss
;
; - Memasang ke Program Files\ReadPaper. AppId tetap, jadi memasang versi baru
;   memperbarui yang lama di tempat yang sama — termasuk folder yang dulu diisi
;   dengan menyalin zip portabel ke sana.
; - Data dan pengaturan (profil repositori, token, clone) ada di
;   %USERPROFILE%\.local\share\readpaper, di luar folder program. Pemasang,
;   pembaruan, dan uninstall tidak pernah menyentuhnya.

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

[Setup]
AppId={{8C6E4F2A-5B1D-4E7A-9C3F-2D1A6B0E7F41}
AppName=ReadPaper
AppVersion={#MyAppVersion}
AppVerName=ReadPaper {#MyAppVersion}
AppPublisher=Hendri Karisma
AppPublisherURL=https://github.com/situkangsayur/readpaper
DefaultDirName={autopf}\ReadPaper
UsePreviousAppDir=yes
DisableProgramGroupPage=yes
DisableDirPage=auto
OutputDir=..\..\dist
OutputBaseFilename=readpaper-{#MyAppVersion}-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
; ReadPaper yang sedang terbuka ditutup dulu, supaya berkasnya bisa diganti.
CloseApplications=yes
RestartApplications=no
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\readpaper.exe
UninstallDisplayName=ReadPaper
WizardStyle=modern
LicenseFile=..\..\LICENSE
ChangesAssociations=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Buat ikon ReadPaper di desktop"; GroupDescription: "Ikon tambahan:"

[InstallDelete]
; Aset aplikasi dan git bawaan versi lama dibuang dulu supaya tidak ada sisa
; berkas usang bercampur dengan yang baru. Ini folder program, bukan data
; pengguna.
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{app}\git"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\ReadPaper"; Filename: "{app}\readpaper.exe"
Name: "{autodesktop}\ReadPaper"; Filename: "{app}\readpaper.exe"; Tasks: desktopicon

[Registry]
; "Buka dengan → ReadPaper" untuk PDF dan EPUB, tanpa merebut aplikasi bawaan.
Root: HKA; Subkey: "Software\Classes\Applications\readpaper.exe"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "ReadPaper"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\readpaper.exe\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\readpaper.exe"" ""%1"""; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.pdf\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\.epub\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey

[Run]
Filename: "{app}\readpaper.exe"; Description: "Jalankan ReadPaper"; Flags: nowait postinstall skipifsilent
