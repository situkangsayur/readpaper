; Pemasang ReadPaper untuk Windows (Inno Setup 6).
;
;
; Bahasa: Indonesia (berkas Indonesian.isl di folder ini — terjemahan tidak
; resmi Inno Setup, disimpan di repo supaya CI tidak bergantung padanya) dan
; English. Bila ReadPaper sudah terpasang, halaman pertama menawarkan Perbarui
; (atau Perbaiki untuk versi yang sama), Ubah, atau Hapus.
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
Name: "id"; MessagesFile: "Indonesian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
id.DesktopIcon=Buat ikon ReadPaper di desktop
en.DesktopIcon=Create a ReadPaper desktop icon
id.ExtraIcons=Ikon tambahan:
en.ExtraIcons=Additional icons:
id.OpenWith=Tampilkan ReadPaper di "Buka dengan" untuk PDF dan EPUB
en.OpenWith=Show ReadPaper in "Open with" for PDF and EPUB
id.Integration=Integrasi:
en.Integration=Integration:
id.RunApp=Jalankan ReadPaper
en.RunApp=Launch ReadPaper
id.MaintTitle=ReadPaper sudah terpasang
en.MaintTitle=ReadPaper is already installed
id.MaintDesc=Versi terpasang: %1. Pilih yang ingin dilakukan.
en.MaintDesc=Installed version: %1. Choose what to do.
id.MaintNote=Library, profil repositori, token, dan clone tidak tersentuh oleh pilihan mana pun.
en.MaintNote=Libraries, repository profiles, tokens and clones are untouched by every option.
id.MaintUpdate=Perbarui ke versi %1
en.MaintUpdate=Update to version %1
id.MaintRepair=Perbaiki (pasang ulang versi %1)
en.MaintRepair=Repair (reinstall version %1)
id.MaintModify=Ubah pilihan pemasangan (ikon desktop, "Buka dengan")
en.MaintModify=Change installed options (desktop icon, "Open with")
id.MaintRemove=Hapus ReadPaper dari komputer ini
en.MaintRemove=Remove ReadPaper from this computer
id.RemoveFailed=Uninstaller ReadPaper tidak bisa dijalankan.
en.RemoveFailed=The ReadPaper uninstaller could not be started.

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopIcon}"; GroupDescription: "{cm:ExtraIcons}"
Name: "openwith"; Description: "{cm:OpenWith}"; GroupDescription: "{cm:Integration}"

[InstallDelete]
; Aset aplikasi dan git bawaan versi lama dibuang dulu supaya tidak ada sisa
; berkas usang bercampur dengan yang baru. Ini folder program, bukan data
; pengguna.
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{app}\git"
; "Ubah" yang mematikan ikon desktop: ikon lama dibuang, karena tugas yang
; tidak dipilih tidak menghapus apa yang dulu dibuatnya.
Type: files; Name: "{autodesktop}\ReadPaper.lnk"; Check: not WizardIsTaskSelected('desktopicon')

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\ReadPaper"; Filename: "{app}\readpaper.exe"
Name: "{autodesktop}\ReadPaper"; Filename: "{app}\readpaper.exe"; Tasks: desktopicon

[Registry]
; "Buka dengan → ReadPaper" untuk PDF, EPUB, Word, PowerPoint, dan Excel, tanpa
; merebut aplikasi bawaan.
Root: HKA; Subkey: "Software\Classes\Applications\readpaper.exe"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "ReadPaper"; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\Applications\readpaper.exe\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\readpaper.exe"" ""%1"""; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\.pdf\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\.epub\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\.doc\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\.docx\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\.rtf\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\.ppt\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\.pptx\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\.pps\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\.ppsx\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\.xls\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey; Tasks: openwith
Root: HKA; Subkey: "Software\Classes\.xlsx\OpenWithList\readpaper.exe"; ValueType: none; Flags: uninsdeletekey; Tasks: openwith

[Run]
Filename: "{app}\readpaper.exe"; Description: "{cm:RunApp}"; Flags: nowait postinstall skipifsilent


[Code]
{ Pemasang yang mengenali pemasangan sebelumnya.

  Dulu menjalankan setup.exe di atas versi terpasang langsung menimpa tanpa
  bertanya. Sekarang, bila ReadPaper sudah ada, halaman pertama menawarkan:
  perbarui (atau perbaiki bila versinya sama), ubah pilihan, atau hapus.
  Mode senyap (CI, pembaruan otomatis) melewati halaman ini dan memperbarui. }

const
  UninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{8C6E4F2A-5B1D-4E7A-9C3F-2D1A6B0E7F41}_is1';

var
  MaintPage: TInputOptionWizardPage;
  InstalledVersion: String;
  UninstallCmd: String;

function ReadInstalled(): Boolean;
begin
  Result :=
    (RegQueryStringValue(HKLM, UninstallKey, 'DisplayVersion', InstalledVersion) or
     RegQueryStringValue(HKCU, UninstallKey, 'DisplayVersion', InstalledVersion)) and
    (RegQueryStringValue(HKLM, UninstallKey, 'UninstallString', UninstallCmd) or
     RegQueryStringValue(HKCU, UninstallKey, 'UninstallString', UninstallCmd));
end;

function IsModify(): Boolean;
begin
  Result := (MaintPage <> nil) and MaintPage.Values[1];
end;

procedure InitializeWizard();
var
  first: String;
begin
  MaintPage := nil;
  if not ReadInstalled() then exit;
  if InstalledVersion = '{#MyAppVersion}' then
    first := FmtMessage(CustomMessage('MaintRepair'), ['{#MyAppVersion}'])
  else
    first := FmtMessage(CustomMessage('MaintUpdate'), ['{#MyAppVersion}']);
  MaintPage := CreateInputOptionPage(wpWelcome,
    CustomMessage('MaintTitle'),
    FmtMessage(CustomMessage('MaintDesc'), [InstalledVersion]),
    CustomMessage('MaintNote'), True, False);
  MaintPage.Add(first);
  MaintPage.Add(CustomMessage('MaintModify'));
  MaintPage.Add(CustomMessage('MaintRemove'));
  MaintPage.Values[0] := True;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  { Memperbarui dan memperbaiki memakai pilihan yang lama; hanya "Ubah"
    yang menampilkan halaman tugas lagi. }
  if (MaintPage <> nil) and (PageID = wpSelectTasks) then
    Result := not IsModify();
  if (MaintPage <> nil) and ((PageID = wpLicense) or (PageID = wpSelectDir)) then
    Result := True;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  code: Integer;
begin
  Result := True;
  if (MaintPage <> nil) and (CurPageID = MaintPage.ID) and MaintPage.Values[2] then
  begin
    if Exec(RemoveQuotes(UninstallCmd), '', '', SW_SHOW, ewWaitUntilTerminated, code) then
      WizardForm.Close
    else
      MsgBox(CustomMessage('RemoveFailed'), mbError, MB_OK);
    Result := False;
  end;
end;

procedure DropOpenWith(Root: Integer);
begin
  RegDeleteKeyIncludingSubkeys(Root, 'Software\Classes\Applications\readpaper.exe');
  RegDeleteKeyIncludingSubkeys(Root, 'Software\Classes\.pdf\OpenWithList\readpaper.exe');
  RegDeleteKeyIncludingSubkeys(Root, 'Software\Classes\.epub\OpenWithList\readpaper.exe');
  RegDeleteKeyIncludingSubkeys(Root, 'Software\Classes\.doc\OpenWithList\readpaper.exe');
  RegDeleteKeyIncludingSubkeys(Root, 'Software\Classes\.docx\OpenWithList\readpaper.exe');
  RegDeleteKeyIncludingSubkeys(Root, 'Software\Classes\.rtf\OpenWithList\readpaper.exe');
  RegDeleteKeyIncludingSubkeys(Root, 'Software\Classes\.ppt\OpenWithList\readpaper.exe');
  RegDeleteKeyIncludingSubkeys(Root, 'Software\Classes\.pptx\OpenWithList\readpaper.exe');
  RegDeleteKeyIncludingSubkeys(Root, 'Software\Classes\.pps\OpenWithList\readpaper.exe');
  RegDeleteKeyIncludingSubkeys(Root, 'Software\Classes\.ppsx\OpenWithList\readpaper.exe');
  RegDeleteKeyIncludingSubkeys(Root, 'Software\Classes\.xls\OpenWithList\readpaper.exe');
  RegDeleteKeyIncludingSubkeys(Root, 'Software\Classes\.xlsx\OpenWithList\readpaper.exe');
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  { Sama untuk "Buka dengan": dimatikan lewat "Ubah" berarti entrinya
    dibuang dari registri, bukan sekadar tidak ditulis ulang. }
  if (CurStep = ssInstall) and not WizardIsTaskSelected('openwith') then
  begin
    DropOpenWith(HKLM);
    DropOpenWith(HKCU);
  end;
end;

procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  { Setelah uninstall selesai, menutup pemasang tidak perlu dikonfirmasi. }
  if (MaintPage <> nil) and MaintPage.Values[2] then Confirm := False;
end;
