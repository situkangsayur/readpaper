// Manual check of GitHubApiClient against the real GitHub API.
// Not named `*_test.dart` on purpose: `flutter test` skips it, and it needs
// network access. Reads a public repository, so no token is required.
// Run explicitly: flutter test test/_real_github_api_check.dart
// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/sync/data/datasources/github_api_client.dart';
import 'package:readpaper/src/features/sync/data/datasources/github_sync_state.dart';

void main() {
  test('reads a real repository tree and a real blob', () async {
    final ref = GitHubRepoRef.parse('https://github.com/octocat/Hello-World')!;
    final client = GitHubApiClient(ref: ref, token: null);
    addTearDown(client.close);

    final branch = await client.defaultBranch();
    print('default branch: $branch');

    final head = await client.headSha(branch);
    print('head: $head');
    expect(head, hasLength(40));

    final entries = await client.tree(head);
    print('tree entries: ${entries.length}');
    expect(entries, isNotEmpty);

    final blobEntry = entries.firstWhere((e) => e.isBlob);
    final bytes = await client.blob(blobEntry.sha);
    print('${blobEntry.path}: ${bytes.length} bytes, sisa kuota ${client.rateLimitRemaining}');

    expect(
      gitBlobSha(bytes),
      blobEntry.sha,
      reason: 'the blob we downloaded must hash back to the id GitHub listed',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}
