import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ioniq6_companion/update/updater.dart';

void main() {
  test('compares versions', () {
    expect(Updater.isNewer('0.2.0', '0.1.0'), isTrue);
    expect(Updater.isNewer('0.1.10', '0.1.9'), isTrue);
    expect(Updater.isNewer('1.0', '0.9.9'), isTrue);
    expect(Updater.isNewer('0.1.0', '0.1.0+7'), isFalse);
    expect(Updater.isNewer('0.1.0', '0.2.0'), isFalse);
  });

  Updater withLatest(int status, Map<String, dynamic> body) => Updater(
    client: MockClient((r) async {
      expect(r.url.path, '/repos/arshad1416/ioniq6-app/releases/latest');
      return http.Response(jsonEncode(body), status);
    }),
  );

  final release = {
    'tag_name': 'v0.2.0',
    'body': 'Faster lock',
    'assets': [
      {'name': 'ioniq6-companion.apk', 'browser_download_url': 'https://example.com/a.apk', 'size': 52000000},
    ],
  };

  test('offers a newer release with its APK', () async {
    final r = await withLatest(200, release).newerThan('0.1.0');
    expect(r?.version, '0.2.0');
    expect(r?.notes, 'Faster lock');
    expect(r?.apkUrl, 'https://example.com/a.apk');
  });

  test('stays quiet when up to date, unreleased, or without an APK', () async {
    expect(await withLatest(200, release).newerThan('0.2.0'), isNull);
    expect(await withLatest(404, {}).newerThan('0.1.0'), isNull);
    expect(await withLatest(200, {...release, 'assets': []}).newerThan('0.1.0'), isNull);
  });
}
