import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:readpaper/src/features/sync/data/datasources/github_api_client.dart';

/// Berkas di atas batas API blob dikirim sebagai paket git ke
/// `git-receive-pack`, lalu ref sementaranya dihapus.
void main() {
  List<int> pkt(String line) =>
      ascii.encode((line.length + 4).toRadixString(16).padLeft(4, '0') + line);

  test('berkas besar dikirim sebagai paket git yang sah', () async {
    final content = Uint8List(GitHubApiClient.maxApiBlobBytes + 1);
    for (var i = 0; i < content.length; i++) {
      content[i] = (i * 31) & 0xff;
    }
    Uint8List? sent;
    final deleted = <String>[];
    final client = GitHubApiClient(
      ref: const GitHubRepoRef(owner: 'o', repo: 'r'),
      token: 't',
      client: MockClient((request) async {
        if (request.url.path == '/o/r.git/git-receive-pack') {
          expect(request.headers['Authorization'], startsWith('Basic '));
          sent = request.bodyBytes;
          final ref = RegExp(
            r'refs/readpaper/blob-[0-9a-f]{40}',
          ).firstMatch(latin1.decode(request.bodyBytes.sublist(0, 200)))!.group(0)!;
          return http.Response.bytes(<int>[
            ...pkt('unpack ok\n'),
            ...pkt('ok $ref\n'),
            ...ascii.encode('0000'),
          ], 200);
        }
        if (request.method == 'DELETE') {
          deleted.add(request.url.path);
          return http.Response('', 204);
        }
        if (request.url.path.endsWith('/git/blobs')) fail('API blob tidak boleh dipakai');
        return http.Response('tidak dikenal', 404);
      }),
    );

    final sha = await client.createBlob(content);

    final dir = Directory.systemTemp.createTempSync('rp_pack_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/berkas')..writeAsBytesSync(content);
    final expected = (await Process.run('git', <String>[
      'hash-object',
      file.path,
    ])).stdout.toString().trim();
    expect(sha, expected);

    // Bagian setelah "0000" adalah paketnya; git sendiri yang memeriksa.
    final body = sent!;
    final start = latin1.decode(body.sublist(0, 300)).indexOf('0000PACK') + 4;
    final pack = File('${dir.path}/kiriman.pack')..writeAsBytesSync(body.sublist(start));
    await Process.run('git', <String>['init', '-q', dir.path]);
    final check = await Process.run('git', <String>[
      'index-pack',
      pack.path,
    ], workingDirectory: dir.path);
    expect(check.exitCode, 0, reason: '${check.stderr}');
    final verify = await Process.run('git', <String>[
      'verify-pack',
      '-v',
      pack.path.replaceAll('.pack', '.idx'),
    ], workingDirectory: dir.path);
    expect(verify.stdout.toString(), contains('$sha blob'));

    await client.releaseParkedBlobs();
    expect(deleted, <String>['/repos/o/r/git/refs/readpaper/blob-$sha']);
  });

  test('penolakan dari git-receive-pack menjadi penolakan berkas', () async {
    final client = GitHubApiClient(
      ref: const GitHubRepoRef(owner: 'o', repo: 'r'),
      token: 't',
      client: MockClient((request) async {
        final ref = RegExp(
          r'refs/readpaper/blob-[0-9a-f]{40}',
        ).firstMatch(latin1.decode(request.bodyBytes.sublist(0, 200)))!.group(0)!;
        return http.Response.bytes(<int>[
          ...pkt('unpack ok\n'),
          ...pkt('ng $ref pre-receive hook declined\n'),
          ...ascii.encode('0000'),
        ], 200);
      }),
    );
    await expectLater(
      client.createBlob(Uint8List(GitHubApiClient.maxApiBlobBytes + 1)),
      throwsA(isA<Exception>().having((e) => '$e', 'pesan', contains('pre-receive hook declined'))),
    );
  });
}
