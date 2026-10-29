import 'package:flutter/material.dart';

import '../car/car_state.dart';
import '../car/commands.dart';
import '../theme.dart';
import '../widgets/climate_icon.dart';
import '../widgets/common.dart';
import '../widgets/dock.dart';
import '../widgets/hold_button.dart';
import '../widgets/line_icon.dart';
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
                        child: LineIcon(
                          locked ? Glyphs.lock : Glyphs.lockOpen,
                          size: 28,
                          stroke: 1.8,
                          color: locked ? const Color(0xFFE6E6E8) : Palette.red,
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
                        child: const LineIcon(Glyphs.bolt, color: Color(0xFFE6E6E8), size: 28, stroke: 1.8),
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
        const _Switches(),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              DockItem(glyph: const LineIcon(Glyphs.flash), label: 'Flash', command: const FlashCommand()),
              DockItem(glyph: const LineIcon(Glyphs.honk), label: 'Honk', command: const HonkCommand()),
              DockItem(glyph: const ClimateIcon(), label: 'Climate', route: '/climate'),
              DockItem(glyph: const LineIcon(Glyphs.pin), label: 'Find', onTap: () => _find(context)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _find(BuildContext context) async {
    final store = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Asking the car where it is…')));
    try {
      await store.locate();
      final at = store.car.parkedAt;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(at == null ? 'The car didn\'t share its location.' : 'Parked at $at')));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Couldn\'t reach the car: $e')));
    }
  }
}

/// Valet mode and battery preconditioning, each switched with a hold through
/// the Ioniq 6 Extras add-on, in one outlined card.
class _Switches extends StatelessWidget {
  const _Switches();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF3A3A3C)),
    ),
    child: const Column(
      children: [
        _ValetSwitch(),
        Divider(color: Color(0xFF3A3A3C), height: 1),
        _PreconditionSwitch(),
      ],
    ),
  );
}

/// Warms the battery so the next fast charge is quicker (Bluelink
/// preconditioning). Uses some charge, so it's a hold like other commands.
class _PreconditionSwitch extends StatelessWidget {
  const _PreconditionSwitch();

  @override
  Widget build(BuildContext context) {
    final on = AppScope.of(context).car.preconditioningOn;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const LineIcon(Glyphs.thermometer, size: 22, color: Palette.light),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Battery preconditioning', style: Txt.body(16), overflow: TextOverflow.ellipsis),
                Text(
                  switch (on) {
                    true => 'Warming for fast charging',
                    false => 'Warms the battery before a fast charge',
                    null => 'Not set up',
                  },
                  style: Txt.muted(13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          HoldSwitch(
            value: on,
            command: (on) => PreconditionCommand(on: on),
            missing: 'Install the Ioniq 6 Extras add-on in Home Assistant to warm the battery.',
          ),
        ],
      ),
    );
  }
}

/// Valet mode limits what a valet can see and do in the car; the gear opens
/// its settings.
class _ValetSwitch extends StatelessWidget {
  const _ValetSwitch();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final v = store.settings.valet;
    final car = store.car;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const LineIcon(Glyphs.valet, size: 22, color: Palette.light),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Valet mode', style: Txt.body(16)),
                Text(
                  [
                    'Limit ${car.valetMaxSpeed ?? v.speedLimitKmh} km/h',
                    switch (car.valetOn) {
                      true => 'On',
                      false => 'Off',
                      null => 'Not set up',
                    },
                  ].join(' · '),
                  style: Txt.muted(13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Valet settings',
            onPressed: () => Navigator.pushNamed(context, '/valet'),
            style: IconButton.styleFrom(backgroundColor: Palette.unlit, fixedSize: const Size.square(34)),
            icon: const LineIcon(Glyphs.gear, color: Palette.light, size: 18),
          ),
          const ValetToggle(),
        ],
      ),
    );
  }
}
