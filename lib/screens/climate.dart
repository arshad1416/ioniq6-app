import 'package:flutter/material.dart';

import '../car/commands.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/hold_button.dart';
import '../widgets/rive_view.dart';

class ClimateScreen extends StatelessWidget {
  const ClimateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final car = store.car;
    final req = store.settings.climate;
    final on = car.climateOn;
    final cabin = car.cabinTempC;
    final heating = req.tempC >= (cabin ?? 15);
    final progress = cabin == null || !on ? 0.0 : (1 - ((req.tempC - cabin).abs() / 12)).clamp(0.0, 1.0);

    return SubScreen(
      title: 'Climate',
      scroll: false,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              Widget seat(SeatLevel level, void Function() onTap, double x, String label) => Positioned(
                left: box.maxWidth * x - 22,
                top: box.maxHeight * .555 - 22,
                child: Semantics(
                  label: '$label seat heat ${level.name}',
                  button: true,
                  child: GestureDetector(
                    onTap: onTap,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.waves,
                            size: 24,
                            color: level == SeatLevel.off ? const Color(0xFF9A9A9E) : Palette.red,
                          ),
                          Positioned(
                            bottom: 0,
                            child: Text(level.badge, style: Txt.mono(9, weight: 600, color: Palette.red)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              return Stack(
                alignment: Alignment.center,
                children: [
                  Hero(
                    tag: 'car',
                    child: Image.asset(
                      'assets/images/top_v.webp',
                      fit: BoxFit.contain,
                      semanticLabel: 'Cabin from above',
                    ),
                  ),
                  IgnorePointer(
                    child: SizedBox(
                      width: 160,
                      height: 160,
                      child: RiveView(
                        asset: 'assets/rive/ioniq6_climate.riv',
                        values: {'on': on, 'mode': heating ? 1 : 0, 'progress': progress},
                        fallback: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  seat(
                    req.driverSeat,
                    () => store.updateClimate(req.copyWith(driverSeat: req.driverSeat.next)),
                    .31,
                    'Driver',
                  ),
                  seat(
                    req.passengerSeat,
                    () => store.updateClimate(req.copyWith(passengerSeat: req.passengerSeat.next)),
                    .69,
                    'Passenger',
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(color: Palette.raise, borderRadius: BorderRadius.circular(26)),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF3A3A3C), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                Text(
                  cabin == null ? 'Cabin temperature not reported' : 'Inside ${cabin.round()} °C',
                  style: Txt.muted(11),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: HoldButton(
                        enabled: store.pending == null,
                        onHeld: () => runCommand(context, on ? const StopClimateCommand() : StartClimateCommand(req)),
                        builder: (context, p) => Column(
                          children: [
                            HoldRing(
                              progress: p,
                              size: 40,
                              child: Icon(Icons.power_settings_new, size: 28, color: on ? Palette.red : Palette.light),
                            ),
                            Text(
                              store.pending is StartClimateCommand || store.pending is StopClimateCommand
                                  ? 'Sending'
                                  : on
                                  ? 'On'
                                  : 'Off',
                              style: Txt.muted(11),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Cooler',
                              onPressed: req.tempC <= 16
                                  ? null
                                  : () => store.updateClimate(req.copyWith(tempC: req.tempC - .5)),
                              icon: const Icon(Icons.chevron_left, color: Palette.mute),
                            ),
                            Text(
                              '${req.tempC.toStringAsFixed(req.tempC % 1 == 0 ? 0 : 1)}°',
                              style: Txt.display(
                                52,
                                weight: 200,
                              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                            IconButton(
                              tooltip: 'Warmer',
                              onPressed: req.tempC >= 30
                                  ? null
                                  : () => store.updateClimate(req.copyWith(tempC: req.tempC + .5)),
                              icon: const Icon(Icons.chevron_right, color: Palette.mute),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: GestureDetector(
                        onTap: () => store.updateClimate(req.copyWith(wheel: !req.wheel)),
                        child: Column(
                          children: [
                            Icon(Icons.trip_origin, size: 28, color: req.wheel ? Palette.red : Palette.light),
                            const SizedBox(height: 6),
                            Text('Wheel', style: Txt.muted(11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Wide(
                  icon: Icons.window,
                  label: 'Defrost car',
                  on: req.defrost,
                  onTap: () => store.updateClimate(req.copyWith(defrost: !req.defrost)),
                ),
                const SizedBox(height: 10),
                Text(
                  on
                      ? 'Hold the power button to stop.'
                      : 'Hold the power button to start. Runs ${req.minutes} min with these settings.',
                  style: Txt.muted(11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Wide extends StatelessWidget {
  const _Wide({required this.icon, required this.label, required this.on, required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: on ? Palette.red : const Color(0xFF3A3A3C)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: on ? Palette.red : Palette.light),
          const SizedBox(width: 14),
          Text(label, style: Txt.body(14)),
        ],
      ),
    ),
  );
}
