import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/library_index.dart';
import '../../domain/entities/zotero_annotation.dart';
import '../../domain/entities/zotero_item.dart';
import '../../domain/repositories/library_repository.dart';
import '../datasources/repo_layout_detector.dart';
import '../datasources/zotero_fs_datasource.dart';
import '../datasources/zotero_writer.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  const LibraryRepositoryImpl({
    this.detector = const RepoLayoutDetector(),
    this.dataSource = const ZoteroFsDataSource(),
    this.writer = const ZoteroWriter(),
  });

  final RepoLayoutDetector detector;
  final ZoteroFsDataSource dataSource;
  final ZoteroWriter writer;

  @override
  Future<RepoLayout?> detectLayout(String repoRoot) => detector.detect(repoRoot);

  @override
  Future<LibraryIndex> loadLibrary(LibraryRef library) => dataSource.loadLibrary(library);

  @override
  Future<ItemDetail> loadItem(String itemFilePath) => dataSource.loadItemDetail(itemFilePath);

  @override
  File? resolveAttachment({required String libraryDir, required ZoteroAttachment attachment}) {
    final relative = attachment.relativePath;
    if (relative != null && relative.isNotEmpty) {
      final file = File(p.join(libraryDir, relative));
      if (file.existsSync()) return file;
    }
    // Fall back to the canonical layout: attachments/<XX>/<KEY>/<filename>.
    if (attachment.key.isEmpty || attachment.filename.isEmpty) return null;
    final bucket = attachment.key.substring(0, attachment.key.length >= 2 ? 2 : 1);
    for (final root in <String>['attachments', 'attachments-lfs']) {
      final candidate = File(p.join(libraryDir, root, bucket, attachment.key, attachment.filename));
      if (candidate.existsSync()) return candidate;
    }
    return null;
  }

  @override
  File? attachmentLocation({required String libraryDir, required ZoteroAttachment attachment}) {
    final relative = attachment.relativePath;
    if (relative != null && relative.isNotEmpty) {
      return File(p.join(libraryDir, relative));
    }
    if (attachment.key.isEmpty || attachment.filename.isEmpty) return null;
    final bucket = attachment.key.substring(0, attachment.key.length >= 2 ? 2 : 1);
    return File(p.join(libraryDir, 'attachments', bucket, attachment.key, attachment.filename));
  }

  @override
  bool isLfsPointer(File file) {
    try {
      if (file.lengthSync() > 1024) return false;
      final head = file.openSync();
      try {
        final bytes = head.readSync(64);
        return String.fromCharCodes(bytes).startsWith('version https://git-lfs');
      } finally {
        head.closeSync();
      }
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<List<String>> saveAnnotation({
    required String itemFilePath,
    required String libraryDir,
    required ZoteroAnnotation annotation,
  }) => writer.upsertAnnotation(
    itemFilePath: itemFilePath,
    libraryDir: libraryDir,
    annotation: annotation,
  );

  @override
  Future<List<String>> removeAnnotation({
    required String itemFilePath,
    required String libraryDir,
    required String annotationKey,
  }) => writer.deleteAnnotation(
    itemFilePath: itemFilePath,
    libraryDir: libraryDir,
    annotationKey: annotationKey,
  );
}
