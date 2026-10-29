import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../car/car_store.dart';
import '../car/commands.dart';
import '../security/biometrics.dart';
import '../theme.dart';
import 'common.dart';

/// Press and hold for [holdFor] to fire. Anything that acts on the car goes
/// through this so a stray tap never sends a command.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.builder,
    required this.onHeld,
    this.holdFor = const Duration(milliseconds: 900),
    this.enabled = true,
  });

  final Widget Function(BuildContext context, double progress) builder;
  final VoidCallback onHeld;
  final Duration holdFor;
  final bool enabled;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.holdFor)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onHeld();
        _c.value = 0;
      }
    });

  void _down() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    _c.forward(from: 0);
  }

  void _up() {
    if (_c.isAnimating) {
      _c.animateBack(0, duration: const Duration(milliseconds: 200));
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Press and hold to confirm'), duration: Duration(seconds: 1)));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    onLongPress: widget.enabled ? widget.onHeld : null,
    child: Listener(
      onPointerDown: (_) => _down(),
      onPointerUp: (_) => _up(),
      onPointerCancel: (_) => _up(),
      child: AnimatedBuilder(animation: _c, builder: (context, _) => widget.builder(context, _c.value)),
    ),
  );
}

/// Sends [cmd] and reports failures in a snackbar.
Future<void> runCommand(BuildContext context, CarCommand cmd) async {
  final store = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (store.settings.biometricCommands &&
      !store.isDemo &&
      !await Biometrics.confirm('Confirm to ${cmd.label.toLowerCase()}')) {
    messenger.showSnackBar(SnackBar(content: Text('${cmd.label}: not confirmed, nothing sent')));
    return;
  }
  try {
    await store.send(cmd);
    messenger.showSnackBar(
      SnackBar(content: Text(store.isDemo ? '${cmd.label}: demo, nothing sent' : '${cmd.label}: sent')),
    );
  } on CommandsDisabled catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('${cmd.label} failed: $e')));
  }
}

/// Ring drawn around a hold control while it fills.
class HoldRing extends StatelessWidget {
  const HoldRing({super.key, required this.progress, required this.child, this.size = 44});
  final double progress;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (progress > 0)
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              color: Palette.red,
              backgroundColor: Colors.transparent,
            ),
          ),
        child,
      ],
    ),
  );
}
