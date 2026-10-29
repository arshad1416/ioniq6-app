import 'package:flutter/material.dart';

import '../car/car_state.dart';
import '../car/commands.dart';
import '../theme.dart';
import '../widgets/climate_icon.dart';
import '../widgets/common.dart';
import '../widgets/dock.dart';
import '../widgets/hold_button.dart';
import '../widgets/top_car.dart';
import 'valet.dart';

// Where things sit on the overhead car, as fractions of its box (from the mockup).
const _lockSpot = Offset(.467, .47);
const _portSpot = Offset(.96, .82);
const _trunkSpot = Offset(.467, .885);

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
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Center(
              child: TopCar(
                height: box.maxHeight.clamp(0, 520).toDouble(),
                spots: [
                  CarSpot(
                    _trunkSpot,
                    const Size(90, 24),
                    Center(
                      child: Text(
                        'Trunk',
                        style: Txt.body(
                          16,
                          weight: 500,
                          color: const Color(0xFFD9D9DB),
                        ).copyWith(shadows: const [Shadow(blurRadius: 4)]),
                      ),
                    ),
                  ),
                  CarSpot(
                    _lockSpot,
                    const Size.square(56),
                    HoldButton(
                      enabled: store.pending == null,
                      onHeld: () => runCommand(context, locked ? const UnlockCommand() : const LockCommand()),
                      builder: (context, p) => HoldRing(
                        progress: p,
                        size: 48,
                        child: Icon(
                          locked ? Icons.lock_outline : Icons.lock_open,
                          size: 28,
                          color: locked ? const Color(0xFFE6E6E8) : Palette.red,
                          shadows: const [Shadow(blurRadius: 3)],
                        ),
                      ),
                    ),
                  ),
                  CarSpot(
                    _portSpot,
                    const Size.square(48),
                    HoldButton(
                      onHeld: () => runCommand(context, const OpenChargePortCommand()),
                      builder: (context, p) => HoldRing(
                        progress: p,
                        child: const Icon(
                          Icons.bolt,
                          color: Color(0xFFE6E6E8),
                          size: 28,
                          shadows: [Shadow(blurRadius: 3)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
        const _ValetSwitch(),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              DockItem(icon: Icons.highlight, label: 'Flash', command: const FlashCommand()),
              DockItem(icon: Icons.campaign_outlined, label: 'Honk', command: const HonkCommand()),
              DockItem(glyph: const ClimateIcon(), label: 'Climate', route: '/climate'),
              DockItem(icon: Icons.place_outlined, label: 'Find', onTap: () => _find(context)),
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

/// Valet mode limits what a valet can see and do in the car. Bluelink has it
/// (valet/activate, valet/deactivate), but Home Assistant doesn't yet, so the
/// switch stays off. When it's wired up it will need a hold and your PIN.
class _ValetSwitch extends StatelessWidget {
  const _ValetSwitch();

  @override
  Widget build(BuildContext context) {
    final v = AppScope.of(context).settings.valet;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: Palette.raise.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.room_service_outlined, size: 20, color: Palette.mute),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Valet mode', style: Txt.body(16)),
                Text(
                  'Limit ${v.speedLimitKmh} km/h · ${v.pinSet ? 'PIN set' : 'No PIN'}',
                  style: Txt.muted(13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Valet settings',
            onPressed: () => Navigator.pushNamed(context, '/valet'),
            icon: const Icon(Icons.settings_outlined, color: Palette.light, size: 20),
          ),
          GestureDetector(onTap: () => valetComingSoon(context), child: const Switch(value: false, onChanged: null)),
        ],
      ),
    );
  }
}
