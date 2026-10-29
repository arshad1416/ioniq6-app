import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AppRelease {
  const AppRelease({required this.version, required this.notes, required this.apkUrl, required this.size});
  final String version, notes, apkUrl;
  final int size;
}

/// Finds new versions on GitHub Releases and hands the APK to Android's
/// package installer. Releases are tagged `v<version>` with one .apk asset.
class Updater {
  Updater({http.Client? client, this.repo = 'arshad1416/ioniq6-app'}) : _http = client ?? http.Client();

  final http.Client _http;
  final String repo;
  static const _installer = MethodChannel('ioniq6/installer');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The latest release if it is newer than [current], otherwise null.
  Future<AppRelease?> newerThan(String current) async {
    final r = await _http
        .get(
          Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 404) return null; // nothing released yet
    if (r.statusCode != 200) throw HttpException('GitHub answered ${r.statusCode}');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final version = '${j['tag_name']}'.replaceFirst(RegExp('^v'), '');
    final apk = (j['assets'] as List).cast<Map<String, dynamic>>().where((a) => '${a['name']}'.endsWith('.apk'));
    if (apk.isEmpty || !isNewer(version, current)) return null;
    return AppRelease(
      version: version,
      notes: '${j['body'] ?? ''}'.trim(),
      apkUrl: '${apk.first['browser_download_url']}',
      size: (apk.first['size'] as num?)?.toInt() ?? 0,
    );
  }

  /// Compares dotted versions, ignoring any `+build` suffix.
  static bool isNewer(String candidate, String current) {
    List<int> parts(String v) => v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final a = parts(candidate), b = parts(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Downloads the APK into the app's cache, reporting progress from 0 to 1.
  Future<File> download(AppRelease release, void Function(double) onProgress) async {
    final dir = Directory('${(await getApplicationCacheDirectory()).path}/updates');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final file = File('${dir.path}/ioniq6-companion-${release.version}.apk');

    final res = await _http.send(http.Request('GET', Uri.parse(release.apkUrl)));
    if (res.statusCode != 200) throw HttpException('Download failed (${res.statusCode})');
    final total = res.contentLength ?? release.size;
    final sink = file.openWrite();
    var got = 0;
    await for (final chunk in res.stream) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) onProgress(got / total);
    }
    await sink.close();
    return file;
  }

  /// Opens Android's installer for [apk]. The first time, Android asks to
  /// allow installs from this app.
  Future<void> install(File apk) => _installer.invokeMethod('install', {'path': apk.path});
}
