import 'package:flutter/material.dart';

import '../car/commands.dart';
import '../theme.dart';
import 'hold_button.dart';

/// One button in the row of shortcuts along the bottom of a car screen. With
/// [command] it acts on a press and hold; otherwise a tap opens [route].
class DockItem extends StatelessWidget {
  const DockItem({
    super.key,
    this.icon,
    this.glyph,
    required this.label,
    this.command,
    this.route,
    this.onTap,
    this.on = false,
  });
  final IconData? icon;
  final Widget? glyph;
  final String label;
  final CarCommand? command;
  final String? route;
  final VoidCallback? onTap;

  /// Lit red, for the screen you're on.
  final bool on;

  @override
  Widget build(BuildContext context) {
    Widget item(double p) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          HoldRing(
            progress: p,
            size: 36,
            child: IconTheme(
              data: IconThemeData(color: on ? Palette.red : Palette.light, size: 26),
              child: glyph ?? Icon(icon),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Txt.muted(14), maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
        ],
      ),
    );
    final cmd = command;
    return Expanded(
      child: cmd != null
          ? HoldButton(onHeld: () => runCommand(context, cmd), builder: (context, p) => item(p))
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap ?? (route == null ? null : () => Navigator.pushNamed(context, route!)),
              child: item(0),
            ),
    );
  }
}
