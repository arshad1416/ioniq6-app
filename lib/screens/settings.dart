import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../car/car_store.dart';
import '../car/settings.dart';
import '../security/biometrics.dart';
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
            style: Txt.muted(16),
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

  Future<void> _save(void Function(Settings s) change) async {
    change(_store.settings);
    await _store.settings.save();
    if (mounted) setState(() {});
  }

  Future<void> _setBiometric(bool on, void Function(Settings s, bool v) set) async {
    if (on) {
      final messenger = ScaffoldMessenger.of(context);
      if (!await Biometrics.available()) {
        messenger.showSnackBar(const SnackBar(content: Text('Set up a fingerprint or face unlock on the phone first')));
        return;
      }
      if (!await Biometrics.confirm('Confirm it\'s you to turn this on')) return;
    }
    await _save((s) => set(s, on));
  }

  void _soon(String what) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('$what needs Bluelink features Home Assistant doesn\'t have yet. It\'s coming.')),
    );

  Widget _soonRow(IconData icon, String label, {String? sub}) =>
      NavRow(icon: icon, label: label, sub: sub, value: 'Coming soon', onTap: () => _soon(label));

  Widget _switch(String title, String sub, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    title: Text(title, style: Txt.body(16)),
    subtitle: Text(sub, style: Txt.muted(14)),
    value: value,
    onChanged: onChanged,
  );

  Widget _choice<T>(IconData icon, String label, T value, List<(T, String)> options, ValueChanged<T> onChanged) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Palette.mute),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Txt.body(16))),
            SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [for (final (v, l) in options) ButtonSegment(value: v, label: Text(l))],
              selected: {value},
              onSelectionChanged: (v) => onChanged(v.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: Palette.redDeep,
                selectedForegroundColor: Palette.ink,
                foregroundColor: Palette.mute,
                side: const BorderSide(color: Palette.line),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.settings;
    final car = store.car;
    return SubScreen(
      title: 'Settings',
      children: [
        const Lbl('Car'),
        RowsCard(
          children: [
            _soonRow(Icons.people_outline, 'Driver profiles', sub: 'Seat, mirror and climate per driver'),
            _soonRow(Icons.key_outlined, 'Digital Key', sub: 'Unlock and start with your phone'),
            NavRow(
              icon: Icons.directions_walk,
              label: 'Walk-away lock',
              sub: 'Runs in Home Assistant, 45 s after you leave',
              value: car.walkAwayDryRun ? 'Test only' : 'On',
            ),
            NavRow(
              icon: Icons.bluetooth,
              label: 'Phone and car',
              sub: 'OnePlus 13 Bluetooth to IONIQ 6',
              value: car.phoneConnected ? 'Connected' : 'Not connected',
            ),
            _soonRow(Icons.schedule, 'Off-peak charging', sub: 'Charge when power is cheapest'),
            const NavRow(icon: Icons.palette_outlined, label: 'Car colour', value: 'Ultimate Red'),
            _switch(
              'Car commands',
              s.commandsEnabled ? 'On: holding a control acts on the car' : 'Off: the app is read-only',
              s.commandsEnabled,
              _setCommands,
            ),
          ],
        ),
        const Lbl('App'),
        RowsCard(
          children: [
            _choice(Icons.speed, 'Distance & speed', s.miles, const [(false, 'km'), (true, 'mi')], (v) {
              _save((s) => s.miles = v);
              store.refreshViews();
            }),
            _choice(Icons.thermostat, 'Temperature', s.fahrenheit, const [(false, '°C'), (true, '°F')], (v) {
              _save((s) => s.fahrenheit = v);
              store.refreshViews();
            }),
            NavRow(
              icon: Icons.language,
              label: 'Language',
              sub: 'Français is coming',
              value: 'English',
              onTap: () => _soon('Français'),
            ),
            _soonRow(Icons.event_outlined, 'Calendar sync', sub: 'Warm or cool the car before trips'),
            _switch(
              'Live Updates',
              'Charging and climate on the lock screen',
              s.liveUpdates,
              (v) => _save((s) => s.liveUpdates = v),
            ),
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
                style: Txt.muted(14),
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
            _switch('Demo mode', 'Sample data. Nothing is sent anywhere.', s.demo, (v) async {
              s.demo = v;
              await store.applySettings();
            }),
          ],
        ),
        const Lbl('Security & privacy'),
        RowsCard(
          children: [
            _switch(
              'Keep me logged in',
              s.keepLoggedIn ? 'Your Home Assistant token stays on this phone' : 'Forget the token when the app closes',
              s.keepLoggedIn,
              (v) => _save((s) => s.keepLoggedIn = v),
            ),
            _switch(
              'Use biometrics at log in',
              'Fingerprint or face when the app opens',
              s.biometricLogin,
              (v) => _setBiometric(v, (s, v) => s.biometricLogin = v),
            ),
            _switch(
              'Use biometrics for PIN verification',
              'Fingerprint or face before a car command is sent',
              s.biometricCommands,
              (v) => _setBiometric(v, (s, v) => s.biometricCommands = v),
            ),
            _soonRow(Icons.pin_outlined, 'Change PIN', sub: 'Your Bluelink PIN'),
            _soonRow(Icons.password, 'Change password', sub: 'Your Bluelink account'),
            _soonRow(Icons.devices_other, 'Registered devices', sub: 'Phones signed in to Bluelink'),
          ],
        ),
        const Lbl('Help'),
        RowsCard(
          children: [
            NavRow(
              icon: Icons.help_outline,
              label: 'Help & support',
              sub: 'Hyundai Canada owners',
              onTap: () => launchUrl(
                Uri.parse('https://www.hyundaicanada.com/en/owners-section'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            NavRow(
              icon: Icons.emergency_outlined,
              label: 'Emergency services',
              sub: '911, roadside assistance, share location',
              onTap: () => Navigator.pushNamed(context, '/emergency'),
            ),
          ],
        ),
      ],
    );
  }
}
