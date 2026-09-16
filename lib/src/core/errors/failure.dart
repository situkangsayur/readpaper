/// Base class for recoverable errors surfaced to the UI.
class Failure implements Exception {
  const Failure(this.message, {this.details});

  final String message;
  final String? details;

  @override
  String toString() => details == null ? message : '$message\n$details';
}

/// A git command failed.
class GitFailure extends Failure {
  const GitFailure(super.message, {super.details, this.exitCode});

  final int? exitCode;
}

/// The on-disk library could not be read or does not look like a Zotero export.
class LibraryFailure extends Failure {
  const LibraryFailure(super.message, {super.details});
}
