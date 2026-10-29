import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../car/car_store.dart';
import '../theme.dart';
import '../update/update_prompt.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final CarStore _store = AppScope.of(context);
  late final _url = TextEditingController(text: _store.settings.haUrl);
  late final _token = TextEditingController(text: _store.settings.token);
  String? _test;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _test = null;
    });
    final url = _url.text.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      await _store.testConnection(url, _token.text.trim());
      _store.settings
        ..haUrl = url
        ..token = _token.text.trim()
        ..demo = false;
      await _store.applySettings();
      _test = 'Connected';
    } catch (e) {
      _test = 'Couldn\'t connect: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setCommands(bool on) async {
    if (on) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Palette.raise,
          title: Text('Turn on car commands?', style: Txt.display(22, weight: 400)),
          content: Text(
            'Holding a control will then lock, unlock, start climate or charging on the real car through Home Assistant.',
            style: Txt.muted(14),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Turn on')),
          ],
        ),
      );
      if (ok != true) return;
    }
    _store.settings.commandsEnabled = on;
    await _store.settings.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.settings;
    final car = store.car;
    return SubScreen(
      title: 'Settings',
      children: [
        const Lbl('Home Assistant'),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Address', hintText: 'https://pi.tailnet.ts.net:8123'),
        ),
        TextField(
          controller: _token,
          obscureText: true,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Long-lived access token'),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                _test ??
                    switch (store.connection) {
                      Connection.live => 'Connected',
                      Connection.connecting => 'Connecting…',
                      Connection.error => 'Not connected: ${store.error}',
                      Connection.demo => 'Demo mode',
                      Connection.none => 'Not set up',
                    },
                style: Txt.muted(12),
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : _connect,
              style: FilledButton.styleFrom(backgroundColor: Palette.red),
              child: Text(_busy ? 'Testing…' : 'Connect'),
            ),
          ],
        ),
        RowsCard(
          children: [
            SwitchListTile(
              title: Text('Demo mode', style: Txt.body(14)),
              subtitle: Text('Sample data. Nothing is sent anywhere.', style: Txt.muted(12)),
              value: s.demo,
              onChanged: (v) async {
                s.demo = v;
                await store.applySettings();
              },
            ),
            SwitchListTile(
              title: Text('Car commands', style: Txt.body(14)),
              subtitle: Text(
                s.commandsEnabled ? 'On: holding a control acts on the car' : 'Off: the app is read-only',
                style: Txt.muted(12),
              ),
              value: s.commandsEnabled,
              onChanged: _setCommands,
            ),
            SwitchListTile(
              title: Text('Live Updates', style: Txt.body(14)),
              subtitle: Text('Charging and climate on the lock screen', style: Txt.muted(12)),
              value: s.liveUpdates,
              onChanged: (v) async {
                s.liveUpdates = v;
                await s.save();
                setState(() {});
              },
            ),
          ],
        ),
        const Lbl('Runs in Home Assistant'),
        RowsCard(
          children: [
            NavRow(
              icon: Icons.directions_walk,
              label: 'Walk-away lock',
              sub: '45 s after your phone leaves the car',
              value: car.walkAwayDryRun ? 'Test only' : 'On',
            ),
            NavRow(
              icon: Icons.bluetooth,
              label: 'Phone and car',
              sub: 'OnePlus 13 Bluetooth to IONIQ 6',
              value: car.phoneConnected ? 'Connected' : 'Not connected',
            ),
          ],
        ),
        const Lbl('App'),
        RowsCard(
          children: [
            FutureBuilder(
              future: PackageInfo.fromPlatform(),
              builder: (context, info) => NavRow(
                icon: Icons.system_update,
                label: 'Check for updates',
                sub: 'New versions come from GitHub Releases',
                value: info.hasData ? info.data!.version : null,
                onTap: () => checkForUpdate(context, manual: true),
              ),
            ),
          ],
        ),
        Text(
          'Change the walk-away lock in Home Assistant. Car colour: Ultimate Red.',
          style: Txt.muted(11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
