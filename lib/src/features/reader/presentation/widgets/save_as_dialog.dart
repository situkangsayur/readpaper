import 'dart:io';

import '../../../../core/utils/file_pick.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../../core/l10n.dart';

/// Satu folder yang ditawarkan di dialog "Simpan sebagai".
class SaveFolder {
  const SaveFolder({required this.label, required this.path});

  final String label;
  final String path;
}

/// Hasil dialog: jalur berkas yang dipilih, atau permintaan memakai dialog
/// simpan bawaan sistem (untuk tempat di luar jangkauan aplikasi di Android).
class SaveAsChoice {
  const SaveAsChoice.file(String this.path) : systemName = null;
  const SaveAsChoice.system(String this.systemName) : path = null;

  final String? path;
  final String? systemName;
}

/// Nama berkas dari isian pengguna.
class SaveAsNames {
  const SaveAsNames._();

  /// `laporan` → `laporan.pdf`; tanda yang dilarang di Windows dibuang, dan
  /// isian kosong jadi null supaya tombol Simpan bisa mati.
  static String? fileName(String input) {
    var name = input.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
    if (name.toLowerCase().endsWith('.pdf')) name = name.substring(0, name.length - 4).trim();
    if (name.isEmpty || name == '.' || name == '..') return null;
    return '$name.pdf';
  }

  static bool samePath(String a, String b) {
    final x = p.normalize(p.absolute(a));
    final y = p.normalize(p.absolute(b));
    return Platform.isWindows ? x.toLowerCase() == y.toLowerCase() : x == y;
  }
}

/// Menanyakan nama dan tempat PDF yang disimpan.
///
/// Berkas yang sudah ada tidak pernah ditimpa diam-diam: dialog menanyakan
/// Ya atau Tidak lebih dulu, dan "Tidak" kembali ke sini untuk mengganti
/// namanya. Bila yang akan ditimpa adalah berkas yang sedang dibuka,
/// [originalPath], peringatannya menyebut bahwa versi aslinya akan hilang.
Future<SaveAsChoice?> showSaveAsDialog(
  BuildContext context, {
  required String initialName,
  required List<SaveFolder> folders,
  String? initialFolder,
  String? originalPath,
  bool allowPickFolder = false,
  bool allowSystemDialog = true,
}) => showDialog<SaveAsChoice>(
  context: context,
  builder: (_) => _SaveAsDialog(
    initialName: initialName,
    folders: folders,
    initialFolder: initialFolder,
    originalPath: originalPath,
    allowPickFolder: allowPickFolder,
    allowSystemDialog: allowSystemDialog,
  ),
);

class _SaveAsDialog extends StatefulWidget {
  const _SaveAsDialog({
    required this.initialName,
    required this.folders,
    required this.initialFolder,
    required this.originalPath,
    required this.allowPickFolder,
    required this.allowSystemDialog,
  });

  final String initialName;
  final List<SaveFolder> folders;
  final String? initialFolder;
  final String? originalPath;
  final bool allowPickFolder;
  final bool allowSystemDialog;

  @override
  State<_SaveAsDialog> createState() => _SaveAsDialogState();
}

class _SaveAsDialogState extends State<_SaveAsDialog> {
  static const String _pickOther = '\u0000pilih';

  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  late final List<SaveFolder> _folders = <SaveFolder>[...widget.folders];
  late String? _folder = widget.initialFolder ?? (_folders.isEmpty ? null : _folders.first.path);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFolder;
    if (initial != null && !_folders.any((f) => SaveAsNames.samePath(f.path, initial))) {
      _folders.insert(0, SaveFolder(label: p.basename(initial), path: initial));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final picked = await pickDirectoryOrTell(context, title: context.l10n.readerSaveInFolder);
    if (picked == null || !mounted) return;
    setState(() {
      if (!_folders.any((f) => SaveAsNames.samePath(f.path, picked))) {
        _folders.add(SaveFolder(label: picked, path: picked));
      }
      _folder = picked;
    });
  }

  Future<void> _save() async {
    final name = SaveAsNames.fileName(_name.text);
    final folder = _folder;
    if (name == null || folder == null) return;
    final path = p.join(folder, name);

    if (File(path).existsSync()) {
      final original = widget.originalPath;
      final isOriginal = original != null && SaveAsNames.samePath(original, path);
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: Text(context.l10n.readerFileNameTaken),
          content: Text(
            isOriginal
                ? context.l10n.readerOverwriteOriginal(name)
                : context.l10n.readerOverwriteExisting(name),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.readerNo),
            ),
            FilledButton(
              style: isOriginal
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.readerYesOverwrite),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(SaveAsChoice.file(path));
  }

  @override
  Widget build(BuildContext context) {
    final valid = SaveAsNames.fileName(_name.text) != null && _folder != null;
    return AlertDialog(
      title: Text(context.l10n.readerSaveAs),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.readerFileName,
                suffixText: '.pdf',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            if (_folders.isNotEmpty || widget.allowPickFolder)
              DropdownButtonFormField<String>(
                initialValue: _folder,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.l10n.readerSaveIn),
                items: <DropdownMenuItem<String>>[
                  for (final folder in _folders)
                    DropdownMenuItem<String>(
                      value: folder.path,
                      child: Text(folder.label, overflow: TextOverflow.ellipsis),
                    ),
                  if (widget.allowPickFolder)
                    DropdownMenuItem<String>(
                      value: _pickOther,
                      child: Text(context.l10n.readerChooseOtherFolder),
                    ),
                ],
                onChanged: (value) {
                  if (value == _pickOther) {
                    _pickFolder();
                    return;
                  }
                  setState(() => _folder = value);
                },
              ),
            const SizedBox(height: 8),
            Text(context.l10n.readerSaveAsExplain, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: <Widget>[
        if (widget.allowSystemDialog)
          TextButton(
            onPressed: () {
              final name = SaveAsNames.fileName(_name.text) ?? '${widget.initialName}.pdf';
              Navigator.of(context).pop(SaveAsChoice.system(name));
            },
            child: Text(context.l10n.readerOtherPlace),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.readerCancel),
        ),
        FilledButton(onPressed: valid ? _save : null, child: Text(context.l10n.readerSave)),
      ],
    );
  }
}
