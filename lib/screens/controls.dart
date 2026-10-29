import 'package:flutter/material.dart';

import '../car/car_state.dart';
import '../car/commands.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/hold_button.dart';
import '../widgets/rive_view.dart';

/// Rive `Lock.state`: 0 locked, 1 unlocking, 2 unlocked, 3 error, 4 locking.
int riveLockState(DoorLock s) => switch (s) {
  DoorLock.locked => 0,
  DoorLock.unlocking => 1,
  DoorLock.unlocked => 2,
  DoorLock.error => 3,
  DoorLock.locking => 4,
  DoorLock.unknown => 0,
};

/// The overhead photo Arshad picked for this screen, and where things sit on it
/// as fractions of the image.
const _photo = 'assets/images/controls_top.webp';
const _photoSize = Size(768, 1376);
// Centre of the sunroof glass, which runs from 43% to 55.5% of the photo height.
const _lockSpot = Offset(.5, .493);
const _portSpot = Offset(.735, .76);
const _trunkSpot = Offset(.5, .69);

class ControlsScreen extends StatelessWidget {
  const ControlsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final car = store.car;
    final lock = store.lockState;
    final locked = lock == DoorLock.locked || lock == DoorLock.locking;

    return SubScreen(
      title: 'Controls',
      scroll: false,
      background: LayoutBuilder(
        builder: (context, box) {
          // Same maths as BoxFit.cover, so overlays land on the right part of the car.
          final scale = [
            box.maxWidth / _photoSize.width,
            box.maxHeight / _photoSize.height,
          ].reduce((a, b) => a > b ? a : b);
          final shown = _photoSize * scale;
          final origin = Offset((box.maxWidth - shown.width) / 2, (box.maxHeight - shown.height) / 2);

          Widget place(Offset f, double size, Widget child) {
            final p = origin + Offset(f.dx * shown.width, f.dy * shown.height);
            return Positioned(left: p.dx - size / 2, top: p.dy - size / 2, width: size, height: size, child: child);
          }

          return Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF28292C), Color(0xFF161618)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Hero(
                  tag: 'car',
                  child: Image.asset(_photo, fit: BoxFit.cover, semanticLabel: 'Your Ioniq 6 from above'),
                ),
              ),
              place(
                _trunkSpot,
                80,
                Center(
                  child: Text('Trunk', style: Txt.body(14, weight: 500, color: const Color(0xFFD9D9DB))),
                ),
              ),
              place(
                _lockSpot,
                104,
                HoldButton(
                  enabled: store.pending == null,
                  onHeld: () => runCommand(context, locked ? const UnlockCommand() : const LockCommand()),
                  builder: (context, p) => RiveView(
                    asset: 'assets/rive/ioniq6_lock.riv',
                    values: {'state': riveLockState(lock), 'holdProgress': p},
                    fallback: Center(
                      child: HoldRing(
                        progress: p,
                        size: 60,
                        child: Icon(
                          locked ? Icons.lock_outline : Icons.lock_open,
                          size: 30,
                          color: locked ? Palette.ink : Palette.red,
                          shadows: const [Shadow(blurRadius: 6)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              place(
                _portSpot,
                48,
                HoldButton(
                  onHeld: () => runCommand(context, const OpenChargePortCommand()),
                  builder: (context, p) => HoldRing(
                    progress: p,
                    child: const Icon(Icons.bolt, color: Color(0xFFE6E6E8), size: 26, shadows: [Shadow(blurRadius: 6)]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      children: [
        const Spacer(),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            StatusChip(
              car.openDoors.isEmpty ? 'Doors closed' : '${car.openDoors.join(', ')} open',
              ok: car.openDoors.isEmpty,
            ),
            StatusChip(car.trunkOpen ? 'Trunk open' : 'Trunk closed', ok: !car.trunkOpen),
            StatusChip(car.hoodOpen ? 'Hood open' : 'Hood closed', ok: !car.hoodOpen),
          ],
        ),
        Text(
          'Hold the lock to ${locked ? 'unlock' : 'lock'} · hold the bolt to open the charge port',
          textAlign: TextAlign.center,
          style: Txt.muted(11),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              _Dock(icon: Icons.highlight, label: 'Flash', command: const FlashCommand()),
              _Dock(icon: Icons.campaign_outlined, label: 'Honk', command: const HonkCommand()),
              _Dock(icon: Icons.ac_unit, label: 'Climate', route: '/climate'),
              _Dock(icon: Icons.place_outlined, label: 'Find', onTap: () => _find(context)),
            ],
          ),
        ),
      ],
    );
  }

  void _find(BuildContext context) {
    final loc = AppScope.of(context).car.location;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          loc == null
              ? 'The car isn\'t sharing its location with Home Assistant right now.'
              : 'Car is at ${loc.$1.toStringAsFixed(5)}, ${loc.$2.toStringAsFixed(5)}',
        ),
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.icon, required this.label, this.command, this.route, this.onTap});
  final IconData icon;
  final String label;
  final CarCommand? command;
  final String? route;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget item(double p) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          HoldRing(
            progress: p,
            size: 36,
            child: Icon(icon, color: Palette.light, size: 26),
          ),
          const SizedBox(height: 4),
          Text(label, style: Txt.muted(12), maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
        ],
      ),
    );
    final cmd = command;
    return Expanded(
      child: cmd != null
          ? HoldButton(onHeld: () => runCommand(context, cmd), builder: (context, p) => item(p))
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap ?? () => Navigator.pushNamed(context, route!),
              child: item(0),
            ),
    );
  }
}
