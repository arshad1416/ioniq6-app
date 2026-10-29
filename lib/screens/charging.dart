import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../car/commands.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/hold_button.dart';
import '../widgets/rive_view.dart';

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
                _Battery(soc),
                const SizedBox(width: 8),
                Text('$soc%', style: Txt.display(22, weight: 400, color: Palette.red)),
                if (car.charging) const Icon(Icons.bolt, color: Palette.red, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              car.charging
                  ? '${duration(car.chargeMinutesLeft ?? 0)} to charge limit'
                  : '${car.rangeKm ?? '–'} km · ${car.plugged ? 'plugged in' : 'unplugged'}',
              style: Txt.muted(12),
            ),
          ],
        ),
        SizedBox(
          height: 160,
          child: Hero(
            tag: 'car',
            child: Image.asset('assets/images/car.webp', fit: BoxFit.contain),
          ),
        ),
        AspectRatio(
          aspectRatio: 373 / 72,
          child: RiveView(
            asset: 'assets/rive/ioniq6_charge.riv',
            values: {'soc': soc, 'kw': car.chargeKw ?? 0, 'charging': car.charging, 'plugged': car.plugged},
            fallback: Center(
              child: PixelBar(pct: soc, width: double.infinity, limit: limit),
            ),
          ),
        ),
        Panel(
          children: [
            Row(
              children: [
                Text('Charge limit: $limit%', style: Txt.body(13, weight: 500)),
                Flexible(
                  child: Text(
                    car.charging ? ' · Charging' : (car.plugged ? ' · Plugged in' : ' · Unplugged'),
                    style: Txt.muted(13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (car.charging && car.chargeKw != null)
              Text('${car.chargeKw!.toStringAsFixed(1)} kW', style: Txt.muted(13)),
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
          ],
        ),
        Panel(
          children: [
            if (car.stationChargeMinutes != null) Kv('Home charger (L2) to limit', duration(car.stationChargeMinutes!)),
            if (car.fastChargeMinutes != null) Kv('Fast charger to limit', duration(car.fastChargeMinutes!)),
            Kv('DC fast charge limit', '${car.dcLimit}%'),
          ],
        ),
        Text('Start, stop and limit changes need a press and hold.', textAlign: TextAlign.center, style: Txt.muted(11)),
      ],
    );
  }
}

class _Battery extends StatelessWidget {
  const _Battery(this.soc);
  final int soc;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 18,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: Palette.unlit, borderRadius: BorderRadius.circular(4)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: soc / 100,
          child: Container(
            decoration: BoxDecoration(color: Palette.red, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ),
      Container(width: 2, height: 6, color: Palette.unlit),
    ],
  );
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
        child: Center(child: Text(label, style: Txt.muted(13))),
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
            child: Center(child: Text(label, style: Txt.body(14, weight: 500))),
          ),
        ],
      ),
    ),
  );
}
