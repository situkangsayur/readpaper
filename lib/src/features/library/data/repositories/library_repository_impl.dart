import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/library_index.dart';
import '../../domain/entities/zotero_collection.dart';
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
  Future<List<String>> removeItem({required String libraryDir, required String itemFilePath}) =>
      writer.deleteItem(libraryDir: libraryDir, itemFilePath: itemFilePath);

  @override
  Future<ZoteroCollection> createCollection({
    required String libraryDir,
    required String name,
    String? parentKey,
  }) => const ZoteroWriter().createCollection(
    libraryDir: libraryDir,
    name: name,
    parentKey: parentKey,
  );

  @override
  Future<List<String>> renameCollection({
    required String libraryDir,
    required String key,
    required String name,
  }) => const ZoteroWriter().renameCollection(libraryDir: libraryDir, key: key, name: name);

  @override
  Future<List<String>> moveCollection({
    required String libraryDir,
    required String key,
    required String? newParentKey,
  }) => const ZoteroWriter().moveCollection(
    libraryDir: libraryDir,
    key: key,
    newParentKey: newParentKey,
  );

  @override
  Future<List<String>> deleteCollection({
    required String libraryDir,
    required String key,
    required bool withChildren,
  }) => const ZoteroWriter().deleteCollection(
    libraryDir: libraryDir,
    key: key,
    withChildren: withChildren,
  );

  @override
  Future<({int children, int items})> collectionReach(String libraryDir, String key) =>
      const ZoteroWriter().collectionReach(libraryDir, key);

  @override
  Future<List<String>> setItemCollections({
    required String libraryDir,
    required String itemFilePath,
    required List<String> collectionKeys,
    required List<String> collectionPaths,
  }) => const ZoteroWriter().setItemCollections(
    itemFilePath: itemFilePath,
    libraryDir: libraryDir,
    collectionKeys: collectionKeys,
    collectionPaths: collectionPaths,
  );

  @override
  Future<CreatedItem> addPdfAsItem({
    required String libraryDir,
    required String libraryName,
    required int libraryId,
    required String pdfPath,
    required String title,
    String? collectionKey,
    String? collectionPath,
  }) => writer.createItemFromPdf(
    libraryDir: libraryDir,
    libraryName: libraryName,
    libraryId: libraryId,
    pdfPath: pdfPath,
    title: title,
    collectionKey: collectionKey,
    collectionPath: collectionPath,
  );

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
