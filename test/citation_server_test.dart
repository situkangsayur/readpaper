import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/core/utils/app_paths.dart';
import 'package:readpaper/src/features/citation/data/citation_server.dart';
import 'package:readpaper/src/features/citation/data/citation_token_store.dart';
import 'package:readpaper/src/features/library/domain/entities/library_index.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_annotation.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_item.dart';
import 'package:readpaper/src/features/settings/data/datasources/settings_local_datasource.dart';

const String _token = 'token-uji-yang-cukup-panjang-untuk-server-sitasi';

ZoteroItem _item(
  String key,
  String title, {
  List<String> authors = const <String>[],
  String year = '',
  String abstract = '',
  DateTime? added,
  List<String> collections = const <String>[],
  int annotations = 0,
}) => ZoteroItem(
  key: key,
  title: title,
  itemType: 'journalArticle',
  filePath: '/tidak/ada/$key.json',
  creators: <String>[for (final a in authors) '$a, X.'],
  creatorDetails: <ZoteroCreator>[
    for (final a in authors) ZoteroCreator(creatorType: 'author', lastName: a, firstName: 'X.'),
  ],
  year: year,
  date: year,
  abstractNote: abstract,
  dateAdded: added,
  collectionPaths: collections,
  annotationCount: annotations,
  publication: 'Nature Communications',
);

LibraryIndex _index() {
  final items = <ZoteroItem>[
    _item(
      '2T4TVLLZ',
      'Barren plateaus in quantum neural network training landscapes',
      authors: <String>['McClean', 'Boixo', 'Smelyanskiy', 'Babbush', 'Neven'],
      year: '2018',
      abstract: 'Gradient-based hybrid quantum-classical algorithms.',
      added: DateTime(2020),
      collections: <String>['PhD/QML'],
      annotations: 2,
    ),
    _item(
      'AAAA1111',
      'Attention is all you need',
      authors: <String>['Vaswani', 'Shazeer'],
      year: '2017',
      abstract: 'The dominant sequence transduction models are recurrent.',
      added: DateTime(2023),
    ),
    _item(
      'BBBB2222',
      'Deep residual learning',
      authors: <String>['He'],
      year: '2016',
      abstract: 'Residual networks are easier to optimize.',
      added: DateTime(2021),
    ),
  ];
  return LibraryIndex(
    library: const LibraryRef(name: 'My Library', directoryName: 'my-library', directoryPath: '/x'),
    collections: const {},
    roots: const [],
    items: <String, ZoteroItem>{for (final i in items) i.key: i},
    itemsByCollection: const {},
    unfiledItemKeys: const [],
    builtAt: DateTime(2024),
  );
}

ItemDetail _detail(ZoteroItem item) => ItemDetail(
  item: item,
  rawJson: const <String, dynamic>{},
  annotations: <ZoteroAnnotation>[
    const ZoteroAnnotation(
      key: 'ANN00002',
      parentItemKey: 'PDF1',
      type: AnnotationType.underline,
      color: '#2ea8e5',
      pageIndex: 13,
      text: 'kedua',
      sortIndex: '00013|000100|00010',
    ),
    const ZoteroAnnotation(
      key: 'AB12CD34',
      parentItemKey: 'PDF1',
      type: AnnotationType.highlight,
      color: '#ffd400',
      pageIndex: 11,
      text: 'Barren plateau',
      comment: 'inti argumennya',
      pageLabel: '12',
      sortIndex: '00011|000010|00100',
    ),
  ],
);

void main() {
  late CitationServer server;
  late HttpClient client;
  late Uri base;
  LibraryIndex? library;

  setUp(() async {
    library = _index();
    server = CitationServer(
      source: CitationSource(
        index: () => library,
        loadDetail: (item) async => _detail(item),
        // Berkas gaya dan locale yang sungguhan, langsung dari disk.
        loadAsset: (path) => File('assets/csl/$path').readAsString(),
        version: '0.25.0',
      ),
      token: _token,
      port: 0,
    );
    await server.start();
    base = Uri.parse('http://127.0.0.1:${server.boundPort}');
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
  });

  Future<({int status, HttpHeaders headers, String body})> send(
    String method,
    String path, {
    bool auth = true,
    Object? json,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final request = await client.openUrl(method, base.resolve(path));
    if (auth) request.headers.set('Authorization', 'Bearer $_token');
    headers.forEach(request.headers.set);
    if (json != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(json));
    }
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    return (status: response.statusCode, headers: response.headers, body: body);
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final r = await send('GET', path);
    expect(r.status, 200, reason: r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  List<String> keysOf(Map<String, dynamic> body) => <String>[
    for (final item in body['items'] as List) (item as Map)['key'] as String,
  ];

  test('ping tidak butuh token dan menyebut library yang terbuka', () async {
    final r = await send('GET', '/api/ping', auth: false);
    expect(r.status, 200);
    expect(jsonDecode(r.body), <String, Object?>{
      'app': 'ReadPaper',
      'version': '0.25.0',
      'api': 1,
      'library': 'My Library',
    });
    library = null;
    final none = jsonDecode((await send('GET', '/api/ping', auth: false)).body) as Map;
    expect(none.containsKey('library'), isTrue);
    expect(none['library'], isNull);
  });

  test('tanpa token atau dengan token salah dijawab 401 berbahasa Indonesia', () async {
    for (final path in <String>['/api/search', '/api/styles', '/api/tidak-ada']) {
      final r = await send('GET', path, auth: false);
      expect(r.status, 401, reason: path);
      expect((jsonDecode(r.body) as Map)['error'], contains('Token'));
    }
    final wrong = await send(
      'GET',
      '/api/search',
      auth: false,
      headers: <String, String>{'Authorization': 'Bearer salah'},
    );
    expect(wrong.status, 401);
  });

  test('token baru langsung berlaku tanpa menyalakan ulang server', () async {
    server.token = 'token-pengganti-yang-juga-cukup-panjang-sekali';
    expect((await send('GET', '/api/styles')).status, 401);
  });

  test('pencarian: judul, pengarang, tahun, abstrak, tanpa peduli huruf besar', () async {
    expect(keysOf(await getJson('/api/search?q=BARREN')), <String>['2T4TVLLZ']);
    expect(keysOf(await getJson('/api/search?q=vaswani')), <String>['AAAA1111']);
    expect(keysOf(await getJson('/api/search?q=2016')), <String>['BBBB2222']);
    expect(keysOf(await getJson('/api/search?q=easier%20to%20optimize')), <String>['BBBB2222']);
    // Setiap kata harus cocok, di medan mana pun.
    expect(keysOf(await getJson('/api/search?q=mcclean%202018')), <String>['2T4TVLLZ']);
    expect(keysOf(await getJson('/api/search?q=mcclean%202017')), isEmpty);
  });

  test('tanpa q: terbaru dulu, dan limit dihormati', () async {
    expect(keysOf(await getJson('/api/search')), <String>['AAAA1111', 'BBBB2222', '2T4TVLLZ']);
    expect(keysOf(await getJson('/api/search?limit=1')), <String>['AAAA1111']);
    expect((await send('GET', '/api/search?limit=nol')).status, 400);
  });

  test('ringkasan hasil pencarian berbentuk seperti di kontrak', () async {
    final body = await getJson('/api/search?q=barren');
    expect((body['items'] as List).single, <String, Object?>{
      'key': '2T4TVLLZ',
      'title': 'Barren plateaus in quantum neural network training landscapes',
      'creators': 'McClean, Boixo, Smelyanskiy dkk.',
      'year': '2018',
      'type': 'journalArticle',
      'collections': <String>['PhD/QML'],
      'annotationCount': 2,
    });
  });

  test('POST /api/items memberi CSL-JSON dan menyebut kunci yang tidak ada', () async {
    final r = await send(
      'POST',
      '/api/items',
      json: <String, Object>{
        'keys': <String>['2T4TVLLZ', 'TIDAKADA'],
      },
    );
    expect(r.status, 200);
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final item = (body['items'] as List).single as Map<String, dynamic>;
    expect(item['id'], '2T4TVLLZ');
    expect(item['type'], 'article-journal');
    expect(item['title'], startsWith('Barren plateaus'));
    expect((item['author'] as List).first, <String, String>{'family': 'McClean', 'given': 'X.'});
    expect(item['issued'], isNotNull);
    expect(body['missing'], <String>['TIDAKADA']);

    final bad = await send('POST', '/api/items', json: <String, Object>{'kunci': 1});
    expect(bad.status, 400);
    expect((jsonDecode(bad.body) as Map)['error'], isA<String>());
    expect((await send('GET', '/api/items')).status, 405);
  });

  test('anotasi item, terurut menurut letaknya di dokumen', () async {
    final body = await getJson('/api/items/2T4TVLLZ/annotations');
    expect(body['annotations'], <Map<String, Object>>[
      <String, Object>{
        'key': 'AB12CD34',
        'type': 'highlight',
        'color': '#ffd400',
        'text': 'Barren plateau',
        'comment': 'inti argumennya',
        'pageLabel': '12',
      },
      // Tanpa label halaman: jatuh ke nomor halamannya.
      <String, Object>{
        'key': 'ANN00002',
        'type': 'underline',
        'color': '#2ea8e5',
        'text': 'kedua',
        'comment': '',
        'pageLabel': '14',
      },
    ]);
    expect((await send('GET', '/api/items/TIDAKADA/annotations')).status, 404);
  });

  test('daftar gaya dari styles.json, termasuk yang dependen', () async {
    final styles = (await getJson('/api/styles'))['styles'] as List;
    final ids = styles.map((s) => (s as Map)['id']).toList();
    expect(ids, containsAll(<String>['apa', 'ieee', 'vancouver-nlm']));
    expect(styles.firstWhere((s) => (s as Map)['id'] == 'vancouver-nlm'), <String, Object?>{
      'id': 'vancouver-nlm',
      'title': 'Vancouver - NLM (citation-sequence)',
      'kind': 'dependent',
      'format': 'numeric',
      'parent': 'nlm-citation-sequence',
    });
  });

  test('gaya dependen dijawab dengan XML induknya', () async {
    final r = await send('GET', '/api/styles/vancouver-nlm');
    expect(r.status, 200);
    expect(r.headers.contentType?.mimeType, 'application/xml');
    expect(r.body, File('assets/csl/styles/nlm-citation-sequence.csl').readAsStringSync());

    final apa = await send('GET', '/api/styles/apa');
    expect(apa.body, File('assets/csl/styles/apa.csl').readAsStringSync());

    final missing = await send('GET', '/api/styles/tidak-ada');
    expect(missing.status, 404);
    expect(missing.headers.contentType?.mimeType, 'application/json');
  });

  test('locale: yang ada dikirim, yang tidak ada jatuh ke en-US', () async {
    final id = await send('GET', '/api/locales/id-ID');
    expect(id.status, 200);
    expect(id.body, File('assets/csl/locales/locales-id-ID.xml').readAsStringSync());
    final english = File('assets/csl/locales/locales-en-US.xml').readAsStringSync();
    final fr = await send('GET', '/api/locales/fr-FR');
    expect(fr.status, 200);
    expect(fr.body, english);
    expect((await send('GET', '/api/locales/..%2F..%2Fpubspec.yaml')).body, english);
  });

  test('CORS memantulkan Origin, dan preflight mengizinkan jaringan privat', () async {
    const origin = 'https://situkangsayur.github.io';
    final r = await send('GET', '/api/ping', headers: <String, String>{'Origin': origin});
    expect(r.headers.value('access-control-allow-origin'), origin);
    expect(r.headers.value('access-control-allow-headers'), 'Authorization, Content-Type');
    expect(r.headers.value('access-control-allow-methods'), 'GET, POST, OPTIONS');

    // Galat pun membawa CORS, kalau tidak add-in hanya melihat "network error".
    final denied = await send(
      'GET',
      '/api/search',
      auth: false,
      headers: <String, String>{'Origin': origin},
    );
    expect(denied.status, 401);
    expect(denied.headers.value('access-control-allow-origin'), origin);

    final preflight = await send(
      'OPTIONS',
      '/api/search',
      auth: false,
      headers: <String, String>{
        'Origin': origin,
        'Access-Control-Request-Method': 'GET',
        'Access-Control-Request-Headers': 'authorization',
        'Access-Control-Request-Private-Network': 'true',
      },
    );
    expect(preflight.status, 204);
    expect(preflight.headers.value('access-control-allow-origin'), origin);
    expect(preflight.headers.value('access-control-allow-private-network'), 'true');
    expect(preflight.headers.value('access-control-allow-methods'), 'GET, POST, OPTIONS');
  });

  test('hanya mendengarkan di loopback', () {
    expect(server.address, InternetAddress.loopbackIPv4);
  });

  test('port yang sudah dipakai melempar SocketException, bukan menggantung', () async {
    final other = CitationServer(source: server.source, token: _token, port: server.boundPort!);
    await expectLater(other.start(), throwsA(isA<SocketException>()));
    expect(other.isRunning, isFalse);
  });

  group('token', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('readpaper-token-');
      AppPaths.debugOverride(dir);
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('dibuat sekali, tersimpan di credentials.json, dan bisa dibuat ulang', () async {
      const local = SettingsLocalDataSource();
      const store = CitationTokenStore(local);
      await local.saveToken(profileId: 'profil-1', token: 'ghp_rahasia');

      final first = await store.loadOrCreate();
      expect(first.length, greaterThanOrEqualTo(32));
      expect(await store.loadOrCreate(), first, reason: 'tidak berganti setiap kali dibuka');

      final saved =
          jsonDecode(File('${dir.path}/credentials.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(saved[CitationTokenStore.credentialKey], first);
      expect(saved['profil-1'], 'ghp_rahasia', reason: 'token GitHub tidak tersentuh');

      final second = await store.regenerate();
      expect(second, isNot(first));
      expect(await store.loadOrCreate(), second);
      expect(await local.tokenFor('profil-1'), 'ghp_rahasia');
    });
  });
}
