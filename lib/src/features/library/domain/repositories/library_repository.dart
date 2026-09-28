import 'dart:io';

import '../../data/datasources/zotero_writer.dart' show CreatedItem;
import '../entities/library_index.dart';
import '../entities/zotero_collection.dart';
import '../entities/zotero_annotation.dart';
import '../entities/zotero_item.dart';

/// Read/write access to the Zotero export inside a cloned repository.
abstract class LibraryRepository {
  /// Finds the libraries inside [repoRoot]; null when the repo has no export.
  Future<RepoLayout?> detectLayout(String repoRoot);

  /// Parses a whole library (runs off the UI isolate).
  Future<LibraryIndex> loadLibrary(LibraryRef library);

  /// Reads one item file including its annotations.
  Future<ItemDetail> loadItem(String itemFilePath);

  /// Absolute path of an attachment, or null when the file is not on disk.
  File? resolveAttachment({required String libraryDir, required ZoteroAttachment attachment});

  /// Where an attachment belongs, whether or not it has been downloaded yet.
  ///
  /// The Android backend needs this to know what to fetch on demand.
  File? attachmentLocation({required String libraryDir, required ZoteroAttachment attachment});

  /// True when the attachment is still an unfetched Git LFS pointer.
  bool isLfsPointer(File file);

  /// Writes (or replaces) an annotation. Returns the files that changed.
  /// Memasukkan sebuah PDF lepas ke dalam library sebagai item baru.
  Future<CreatedItem> addPdfAsItem({
    required String libraryDir,
    required String libraryName,
    required int libraryId,
    required String pdfPath,
    required String title,
    String? collectionKey,
    String? collectionPath,
  });

  /// Membuang item beserta lampiran dan catatannya.
  Future<List<String>> removeItem({required String libraryDir, required String itemFilePath});

  /// Membuat koleksi Zotero baru di dalam library.
  Future<ZoteroCollection> createCollection({
    required String libraryDir,
    required String name,
    String? parentKey,
  });

  /// Memindahkan item ke koleksi lain; daftar kosong berarti tanpa koleksi.
  Future<List<String>> setItemCollections({
    required String libraryDir,
    required String itemFilePath,
    required List<String> collectionKeys,
    required List<String> collectionPaths,
  });

  Future<List<String>> saveAnnotation({
    required String itemFilePath,
    required String libraryDir,
    required ZoteroAnnotation annotation,
  });

  /// Removes an annotation. Returns the files that changed.
  Future<List<String>> removeAnnotation({
    required String itemFilePath,
    required String libraryDir,
    required String annotationKey,
  });
}
