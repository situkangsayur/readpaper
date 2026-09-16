import 'dart:io';

import '../entities/library_index.dart';
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

  /// True when the attachment is still an unfetched Git LFS pointer.
  bool isLfsPointer(File file);

  /// Writes (or replaces) an annotation. Returns the files that changed.
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
