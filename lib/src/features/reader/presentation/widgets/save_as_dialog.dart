import 'dart:io';

import '../../../../core/utils/file_pick.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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
    final picked = await pickDirectoryOrTell(context, title: 'Simpan di folder');
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
          title: const Text('Nama berkas sudah dipakai'),
          content: Text(
            isOriginal
                ? '$name adalah berkas yang sedang dibuka. Menimpanya membuat versi '
                      'aslinya hilang, dan coretannya melebur ke halaman.\n\n'
                      'Timpa berkas aslinya?'
                : '$name sudah ada di folder ini.\n\nTimpa dengan yang baru?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Tidak'),
            ),
            FilledButton(
              style: isOriginal
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ya, timpa'),
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
      title: const Text('Simpan sebagai'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama berkas', suffixText: '.pdf'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            if (_folders.isNotEmpty || widget.allowPickFolder)
              DropdownButtonFormField<String>(
                initialValue: _folder,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Simpan di'),
                items: <DropdownMenuItem<String>>[
                  for (final folder in _folders)
                    DropdownMenuItem<String>(
                      value: folder.path,
                      child: Text(folder.label, overflow: TextOverflow.ellipsis),
                    ),
                  if (widget.allowPickFolder)
                    const DropdownMenuItem<String>(
                      value: _pickOther,
                      child: Text('Pilih folder lain…'),
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
            Text(
              'Berkas yang dibuka tidak disentuh. Setelah ini, Simpan menulis ke '
              'berkas baru ini.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
            child: const Text('Tempat lain…'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        FilledButton(onPressed: valid ? _save : null, child: const Text('Simpan')),
      ],
    );
  }
}
