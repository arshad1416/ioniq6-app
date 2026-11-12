import 'package:flutter/material.dart';

import '../car/car_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Settings section for the fallback path: signing in to Bluelink on this
/// phone, so the app can reach the car when Home Assistant can't.
class BluelinkSetup extends StatefulWidget {
  const BluelinkSetup({super.key});

  @override
  State<BluelinkSetup> createState() => _BluelinkSetupState();
}

class _BluelinkSetupState extends State<BluelinkSetup> {
  late final CarStore _store = AppScope.of(context);
  late final _user = TextEditingController(text: _store.settings.bluelinkUser);
  final _password = TextEditingController();
  final _pin = TextEditingController();
  String? _note;
  bool _busy = false;

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      await action();
    } catch (e) {
      _note = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() => _run(() async {
    _store.settings
      ..bluelinkUser = _user.text.trim()
      ..bluelinkPassword = _password.text
      ..bluelinkPin = _pin.text.trim();
    if (_store.settings.bluelinkCredentials == null) {
      _note = 'Enter your Bluelink email, password and PIN.';
      return;
    }
    final challenge = await _store.directSignIn();
    if (challenge == null) return;
    await _store.bluelink.sendOtp(challenge);
    if (!mounted) return;
    final code = await _askForCode(challenge.email);
    if (code == null || code.isEmpty) {
      _note = 'Sign-in not finished: no code entered.';
      return;
    }
    await _store.directVerify(challenge, code);
  });

  Future<String?> _askForCode(String email) {
    final code = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.raise,
        title: Text('Enter the code', style: Txt.display(22, weight: 400)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bluelink emailed a one-time code to $email to confirm this phone.', style: Txt.muted(16)),
            TextField(
              controller: code,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, code.text), child: const Text('Confirm')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    if (store.directReady) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            store.usingDirect
                ? 'In use now: Home Assistant can\'t reach the car.'
                : 'Ready. Used only when Home Assistant can\'t reach the car.',
            style: Txt.muted(14),
          ),
          if (store.directError != null) Text('Last try: ${store.directError}', style: Txt.muted(14)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : () => _run(store.directSignOut),
              child: const Text('Sign out of Bluelink'),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Optional. Sign in to Bluelink here and the app can still show the car and lock, unlock, '
          'start climate or charging when Home Assistant or its Hyundai integration is down. '
          'Your login and PIN stay in this phone\'s secure storage.',
          style: Txt.muted(14),
        ),
        TextField(
          controller: _user,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Bluelink email'),
        ),
        TextField(
          controller: _password,
          obscureText: true,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Bluelink password'),
        ),
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Bluelink PIN'),
        ),
        Row(
          children: [
            Expanded(child: Text(_note ?? 'Not signed in', style: Txt.muted(14))),
            FilledButton(
              onPressed: _busy ? null : _signIn,
              style: FilledButton.styleFrom(backgroundColor: Palette.red),
              child: Text(_busy ? 'Signing in…' : 'Sign in'),
            ),
          ],
        ),
      ],
    );
  }
}
