import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import 'updater.dart';

const _snoozeKey = 'updateSnooze';
const _snoozeFor = Duration(days: 1);

/// Checks GitHub Releases and, when there's a newer version, asks whether to
/// download it now or later. "Later" stays quiet for a day for that version.
/// With [manual] (from Settings) it always reports the outcome.
Future<void> checkForUpdate(BuildContext context, {bool manual = false, Updater? updater}) async {
  if (!Updater.supported) return;
  final up = updater ?? Updater();
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final current = (await PackageInfo.fromPlatform()).version;
    final release = await up.newerThan(current);
    if (release == null) {
      if (manual) messenger?.showSnackBar(SnackBar(content: Text('You have the latest version ($current)')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final snooze = prefs.getString(_snoozeKey)?.split('|');
    if (!manual && snooze != null && snooze.length == 2 && snooze[0] == release.version) {
      final until = DateTime.fromMillisecondsSinceEpoch(int.tryParse(snooze[1]) ?? 0);
      if (DateTime.now().isBefore(until)) return;
    }
    if (!context.mounted) return;
    final now = await showDialog<bool>(
      context: context,
      builder: (context) => _UpdateDialog(release: release, current: current),
    );
    if (now == true) {
      await prefs.remove(_snoozeKey);
      if (context.mounted) await _downloadAndInstall(context, up, release);
    } else {
      final until = DateTime.now().add(_snoozeFor).millisecondsSinceEpoch;
      await prefs.setString(_snoozeKey, '${release.version}|$until');
    }
  } catch (e) {
    if (manual) messenger?.showSnackBar(SnackBar(content: Text('Couldn\'t check for updates: $e')));
  }
}

Future<void> _downloadAndInstall(BuildContext context, Updater up, AppRelease release) async {
  final progress = ValueNotifier<double>(0);
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: Palette.raise,
      title: Text('Downloading ${release.version}', style: Txt.display(22, weight: 400)),
      content: ValueListenableBuilder(
        valueListenable: progress,
        builder: (context, p, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: p == 0 ? null : p, color: Palette.red, backgroundColor: Palette.unlit),
            const SizedBox(height: 10),
            Text('${(p * 100).round()}%', style: Txt.muted(14)),
          ],
        ),
      ),
    ),
  );
  try {
    final apk = await up.download(release, (p) => progress.value = p);
    nav.pop();
    await up.install(apk);
  } catch (e) {
    nav.pop();
    messenger?.showSnackBar(SnackBar(content: Text('Update failed: $e')));
  } finally {
    progress.dispose();
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.release, required this.current});
  final AppRelease release;
  final String current;

  @override
  Widget build(BuildContext context) {
    final mb = release.size > 0 ? ' · ${(release.size / 1e6).toStringAsFixed(0)} MB' : '';
    return AlertDialog(
      backgroundColor: Palette.raise,
      title: Text('Update available', style: Txt.display(24, weight: 400)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Version ${release.version} is ready. You have $current$mb.', style: Txt.body(16)),
              if (release.notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('WHAT\'S NEW', style: Txt.label()),
                const SizedBox(height: 6),
                Text(release.notes, style: Txt.muted(15)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: Palette.mute),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Palette.red),
          child: const Text('Download'),
        ),
      ],
    );
  }
}
