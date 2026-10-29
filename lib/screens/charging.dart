import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../car/commands.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/charge_cable.dart';
import '../widgets/climate_icon.dart';
import '../widgets/common.dart';
import '../widgets/dock.dart';
import '../widgets/hold_button.dart';
import '../widgets/line_icon.dart';

class ChargingScreen extends StatefulWidget {
  const ChargingScreen({super.key});

  @override
  State<ChargingScreen> createState() => _ChargingScreenState();
}

class _ChargingScreenState extends State<ChargingScreen> {
  int? _draftLimit;
  bool _sliding = false;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final car = store.car;
    final soc = car.soc ?? 0;
    final limit = _draftLimit ?? car.acLimit;
    final changed = _draftLimit != null && _draftLimit != car.acLimit;

    return SubScreen(
      title: 'Charging',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: PixelBar(pct: soc, width: 200, limit: limit, pulse: car.charging && car.plugged),
                ),
                const SizedBox(width: 10),
                RollingNumber('$soc%', style: Txt.display(22, weight: 400, color: Palette.red)),
                if (car.charging) const Icon(Icons.bolt, color: Palette.red, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              car.charging
                  ? '${duration(car.chargeMinutesLeft ?? 0)} to charge limit'
                  : '${store.settings.units.dist(car.rangeKm) ?? '–'} ${store.settings.units.distance} · ${car.plugged ? 'plugged in' : 'unplugged'}',
              style: Txt.muted(14),
            ),
          ],
        ),
        // The car with the connector in its port and the cable to the ground
        // when plugged in; dashes flow along the cable while charging.
        AspectRatio(
          aspectRatio: 360 / 170,
          child: Hero(
            tag: 'car',
            child: ChargingCar(plugged: car.plugged, charging: car.charging),
          ),
        ),
        const Row(
          children: [
            DockItem(glyph: LineIcon(Glyphs.lock), label: 'Lock', route: '/controls'),
            DockItem(glyph: ClimateIcon(), label: 'Climate', route: '/climate'),
            DockItem(glyph: LineIcon(Glyphs.bolt), label: 'Charge', on: true),
            DockItem(glyph: LineIcon(Glyphs.car), label: 'Controls', route: '/controls'),
          ],
        ),
        Panel(
          children: [
            Row(
              children: [
                Text('Charge limit: $limit%', style: Txt.body(15, weight: 500)),
                Flexible(
                  child: Text(
                    car.charging ? ' · Charging' : (car.plugged ? ' · Plugged in' : ' · Unplugged'),
                    style: Txt.muted(15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if ((car.charging || car.homeChargerCharging) && car.chargeRateKw != null)
              RollingNumber(
                [
                  '${car.chargeRateKw!.toStringAsFixed(1)} kW',
                  if (car.homeChargerCharging && car.sessionKwh != null) '+${car.sessionKwh!.toStringAsFixed(1)} kWh',
                ].join(' · '),
                style: Txt.muted(15),
              ),
            // The track thickens while touched, and each 10% step clicks.
            TweenAnimationBuilder<double>(
              tween: Tween(end: _sliding ? 12 : 6),
              duration: Motion.micro,
              curve: Motion.slider,
              builder: (context, h, child) => SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: h),
                child: child!,
              ),
              child: Slider(
                value: limit.toDouble(),
                min: 50,
                max: 100,
                divisions: 5,
                label: '$limit%',
                onChangeStart: (_) => setState(() => _sliding = true),
                onChangeEnd: (_) => setState(() => _sliding = false),
                onChanged: (v) {
                  if (v.round() != limit) HapticFeedback.selectionClick();
                  setState(() => _draftLimit = v.round());
                },
              ),
            ),
            if (changed)
              HoldButton(
                onHeld: () async {
                  await runCommand(context, SetChargeLimitsCommand(_draftLimit!, _draftLimit!));
                  if (mounted) setState(() => _draftLimit = null);
                },
                builder: (context, p) => _HoldBar(progress: p, label: 'Hold to set limit to $_draftLimit%'),
              ),
            const Divider(color: Palette.line, height: 1),
            Row(
              children: [
                Expanded(
                  child: HoldButton(
                    enabled: store.pending == null,
                    onHeld: () =>
                        runCommand(context, car.charging ? const StopChargeCommand() : const StartChargeCommand()),
                    builder: (context, p) => _SplitButton(p, car.charging ? 'Stop charging' : 'Start charging'),
                  ),
                ),
                Container(width: 1, height: 44, color: Palette.line),
                Expanded(
                  child: HoldButton(
                    onHeld: () => runCommand(context, const OpenChargePortCommand()),
                    builder: (context, p) => _SplitButton(p, 'Open charge port'),
                  ),
                ),
              ],
            ),
            if (car.preconditioningOn != null) ...[
              const Divider(color: Palette.line, height: 1),
              HoldButton(
                enabled: store.pending == null,
                onHeld: () => runCommand(context, PreconditionCommand(on: !car.preconditioningOn!)),
                builder: (context, p) =>
                    _SplitButton(p, car.preconditioningOn! ? 'Stop warming battery' : 'Warm battery for fast charging'),
              ),
            ],
          ],
        ),
        Panel(
          children: [
            if (car.stationChargeMinutes != null) Kv('Home charger (L2) to limit', duration(car.stationChargeMinutes!)),
            if (car.fastChargeMinutes != null) Kv('Fast charger to limit', duration(car.fastChargeMinutes!)),
            Kv('DC fast charge limit', '${car.dcLimit}%'),
            if (car.sessionKwh != null)
              Kv(
                car.homeChargerCharging ? 'This session' : 'Last home session',
                _energyCost(car.sessionKwh!, car.sessionCost),
              ),
            if (car.energyMonthKwh != null) Kv('This month', _energyCost(car.energyMonthKwh!, car.costMonth)),
          ],
        ),
        Text('Start, stop and limit changes need a press and hold.', textAlign: TextAlign.center, style: Txt.muted(13)),
      ],
    );
  }
}

class _SplitButton extends StatelessWidget {
  const _SplitButton(this.progress, this.label);
  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: Container(color: Palette.redDeep),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(child: Text(label, style: Txt.muted(15))),
      ),
    ],
  );
}

class _HoldBar extends StatelessWidget {
  const _HoldBar({required this.progress, required this.label});
  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Container(
      color: Palette.unlit,
      child: Stack(
        children: [
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(color: Palette.red),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(child: Text(label, style: Txt.body(16, weight: 500))),
          ),
        ],
      ),
    ),
  );
}

/// "131.5 kWh · $8.94", from Home Assistant's charging energy and cost.
String _energyCost(double kwh, double? cost) =>
    ['${kwh.toStringAsFixed(1)} kWh', if (cost != null) '\$${cost.toStringAsFixed(2)}'].join(' · ');
