import 'package:flutter/material.dart';

import '../theme.dart';
import 'biometrics.dart';

/// Covers the app until a fingerprint or face check passes, when "Use
/// biometrics at log in" is on.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.locked, required this.child});
  final bool locked;
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  late bool _locked = widget.locked;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_asking) return;
    setState(() => _asking = true);
    final ok = await Biometrics.confirm('Unlock IONIQ 6');
    if (mounted) {
      setState(() {
        _asking = false;
        _locked = !ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _locked
      ? Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('IONIQ 6', style: Txt.display(30)),
                const SizedBox(height: 24),
                IconButton.filled(
                  onPressed: _asking ? null : _unlock,
                  iconSize: 36,
                  style: IconButton.styleFrom(backgroundColor: Palette.redDeep, padding: const EdgeInsets.all(18)),
                  icon: const Icon(Icons.fingerprint, color: Palette.red),
                ),
                const SizedBox(height: 12),
                Text('Tap to unlock', style: Txt.muted(15)),
              ],
            ),
          ),
        )
      : widget.child;
}
