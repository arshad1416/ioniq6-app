import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Keeps the latest 360 shots on the phone, so they still show when Home
/// Assistant can't be reached.
class CameraCache {
  CameraCache({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  Directory? _dir;

  /// Finds the app's folder. Until this finishes (or where there is none, as
  /// in tests) nothing is saved or shown.
  Future<void> init() async {
    try {
      _dir = await getApplicationDocumentsDirectory();
    } catch (_) {
      _dir = null;
    }
  }

  /// The saved shot for [view], if there is one.
  File? saved(String view) {
    final dir = _dir;
    if (dir == null) return null;
    final file = File('${dir.path}/camera_$view.jpg');
    return file.existsSync() ? file : null;
  }

  /// Downloads each view's picture. A view that fails keeps its older shot.
  Future<void> save(Map<String, Uri> pictures) async {
    final dir = _dir;
    if (dir == null) return;
    for (final MapEntry(key: view, value: url) in pictures.entries) {
      try {
        final r = await _http.get(url).timeout(const Duration(seconds: 20));
        if (r.statusCode != 200 || r.bodyBytes.isEmpty) continue;
        final file = File('${dir.path}/camera_$view.jpg');
        await file.writeAsBytes(r.bodyBytes, flush: true);
        await FileImage(file).evict();
      } catch (_) {
        // Try again the next time the shots change.
      }
    }
  }
}
