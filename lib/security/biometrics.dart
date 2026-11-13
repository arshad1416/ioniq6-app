import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Fingerprint or face check through Android's biometric prompt, with the
/// screen lock as a fallback.
abstract final class Biometrics {
  static final _auth = LocalAuthentication();

  static Future<bool> available() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> confirm(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (e) {
      debugPrint('Biometrics: $e');
      return false;
    }
  }
}
