import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../car/car_state.dart';
import '../car/car_store.dart';
import '../car/commands.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/climate_icon.dart';
import '../widgets/common.dart';
import '../widgets/hold_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final car = store.car;
    final soc = car.soc ?? 0;
    final units = store.settings.units;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: Palette.red,
          onRefresh: store.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IONIQ 6', style: Txt.display(30).copyWith(letterSpacing: .6)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: store.connection == Connection.live || store.isDemo ? Palette.ok : Palette.amber,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(_subline(store), style: Txt.muted(13), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                    icon: const Icon(Icons.settings_outlined, color: Palette.mute),
                  ),
                ],
              ),
              if (store.connection == Connection.error) ...[
                const SizedBox(height: 10),
                _Banner('Can\'t reach Home Assistant. Retrying.', detail: store.error),
              ],
              if (store.isDemo) ...[
                const SizedBox(height: 10),
                const _Banner(
                  'Demo mode: sample data, nothing is sent to the car.',
                  detail: 'Add your Home Assistant address in Settings.',
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  RollingNumber('${units.dist(car.rangeKm) ?? '–'}', style: Txt.display(34)),
                  Text(' ${units.distance}', style: Txt.display(15)),
                  const SizedBox(width: 12),
                  Flexible(child: PixelBar(pct: soc)),
                  const SizedBox(width: 12),
                  RollingNumber('$soc%', style: Txt.display(15)),
                  if (car.charging) const Icon(Icons.bolt, color: Palette.red, size: 18),
                ],
              ),
              StaggerIn(index: 0, child: _Hero(onTap: () => Navigator.pushNamed(context, '/controls'))),
              StaggerIn(index: 1, child: _QuickActions(store: store)),
              const SizedBox(height: 14),
              StaggerIn(
                index: 2,
                child: RowsCard(
                  children: [
                    NavRow(
                      icon: Icons.directions_car_outlined,
                      label: 'Controls',
                      value: car.allClosed ? _lockWord(store.lockState) : 'Something is open',
                      onTap: () => Navigator.pushNamed(context, '/controls'),
                    ),
                    NavRow(
                      glyph: const ClimateIcon(),
                      label: 'Climate',
                      value: car.climateOn
                          ? 'On · ${units.temp(car.setTempC)}'
                          : 'Off · set ${units.temp(store.settings.climate.tempC)}',
                      onTap: () => Navigator.pushNamed(context, '/climate'),
                    ),
                    NavRow(
                      icon: Icons.bolt_outlined,
                      label: 'Charging',
                      value: car.charging
                          ? 'Charging · ${duration(car.chargeMinutesLeft ?? 0)} left'
                          : '${car.plugged ? 'Plugged in' : 'Unplugged'} · limit ${car.acLimit}%',
                      onTap: () => Navigator.pushNamed(context, '/charging'),
                    ),
                    NavRow(
                      icon: Icons.bar_chart,
                      label: 'Stats',
                      value: '${thousands(units.dist(car.odometerKm))} ${units.distance}',
                      onTap: () => Navigator.pushNamed(context, '/stats'),
                    ),
                    NavRow(
                      icon: Icons.favorite_border,
                      label: 'Health',
                      value: car.healthOk ? 'All good' : 'Needs a look',
                      onTap: () => Navigator.pushNamed(context, '/health'),
                    ),
                    NavRow(
                      icon: Icons.show_chart,
                      label: 'Activity',
                      value: store.activity.isEmpty ? null : store.activity.first.title,
                      onTap: () => Navigator.pushNamed(context, '/activity'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  car.lastUpdated == null
                      ? 'Waiting for Home Assistant'
                      : 'Car reported ${ago(car.lastUpdated)} · via Home Assistant',
                  style: Txt.muted(11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _subline(CarStore store) {
    final car = store.car;
    final parts = [
      _lockWord(store.lockState),
      if (car.charging) 'Charging' else if (car.plugged) 'Plugged in',
      if (car.climateOn) 'Climate on',
      if (car.engineOn) 'On' else 'Parked',
    ];
    return parts.join(' · ');
  }
}

String _lockWord(DoorLock s) => switch (s) {
  DoorLock.locked => 'Locked',
  DoorLock.unlocked => 'Unlocked',
  DoorLock.locking => 'Locking…',
  DoorLock.unlocking => 'Unlocking…',
  DoorLock.error => 'Lock error',
  DoorLock.unknown => 'Lock unknown',
};

class _Banner extends StatelessWidget {
  const _Banner(this.text, {this.detail});
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Palette.redDeep, borderRadius: BorderRadius.circular(14)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: Txt.body(13, color: Palette.ink)),
        if (detail != null) Text(detail!, style: Txt.muted(12), maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 40,
            right: 40,
            bottom: 22,
            height: 26,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [Palette.red.withValues(alpha: .2), Colors.transparent]),
              ),
            ),
          ),
          const Positioned.fill(
            child: Hero(tag: 'car', child: Turntable()),
          ),
        ],
      ),
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.store});
  final CarStore store;

  @override
  Widget build(BuildContext context) {
    final locked = store.lockState == DoorLock.locked || store.lockState == DoorLock.locking;
    return Row(
      children: [
        Expanded(
          child: HoldButton(
            enabled: store.pending == null,
            onHeld: () => runCommand(context, locked ? const UnlockCommand() : const LockCommand()),
            builder: (context, p) => _Qa(
              icon: locked ? Icons.lock_outline : Icons.lock_open,
              label: _lockWord(store.lockState),
              on: locked,
              progress: p,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Qa(
            glyph: const ClimateIcon(),
            label: 'Climate',
            on: store.car.climateOn,
            onTap: () => Navigator.pushNamed(context, '/climate'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Qa(
            icon: Icons.bolt,
            label: 'Charge',
            on: store.car.charging,
            onTap: () => Navigator.pushNamed(context, '/charging'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Qa(
            icon: Icons.directions_car_outlined,
            label: 'Controls',
            onTap: () => Navigator.pushNamed(context, '/controls'),
          ),
        ),
      ],
    );
  }
}

class _Qa extends StatelessWidget {
  const _Qa({this.icon, this.glyph, required this.label, this.on = false, this.onTap, this.progress = 0});
  final IconData? icon;
  final Widget? glyph;
  final String label;
  final bool on;
  final VoidCallback? onTap;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = on ? Palette.red : Palette.ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        decoration: BoxDecoration(color: on ? Palette.redDeep : Palette.raise, borderRadius: BorderRadius.circular(18)),
        child: Column(
          children: [
            HoldRing(
              progress: progress,
              size: 34,
              child: IconTheme(
                data: IconThemeData(color: color, size: 24),
                child: glyph ?? Icon(icon),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Txt.body(11, color: on ? Palette.red : Palette.mute),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Arshad's car as a 36-frame 360° turntable. Drag sideways to turn it; it
/// eases back to the front three-quarter view when let go.
class Turntable extends StatefulWidget {
  const Turntable({super.key});

  static const frames = 36, rest = 4;
  static const _pxPerFrame = 12.0;
  static String frame(int i) => 'assets/images/turntable/turn_${i.toString().padLeft(2, '0')}.webp';

  @override
  State<Turntable> createState() => _TurntableState();
}

class _TurntableState extends State<Turntable> with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..addListener(() => setState(() => _pos = _from + (_to - _from) * Curves.easeOutCubic.transform(_settle.value)));
  static const _quarter = Turntable.frames / 4;
  double _pos = Turntable.rest.toDouble(), _from = 0, _to = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (var i = 0; i < Turntable.frames; i++) {
      precacheImage(AssetImage(Turntable.frame(i)), context);
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _release() {
    // Turn back the short way round.
    var delta = (Turntable.rest - _pos) % Turntable.frames;
    if (delta > Turntable.frames / 2) delta -= Turntable.frames;
    _from = _pos;
    _to = _pos + delta;
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final i = _pos.round() % Turntable.frames;
    return GestureDetector(
      onHorizontalDragStart: (_) => _settle.stop(),
      onHorizontalDragUpdate: (d) {
        final before = (_pos / _quarter).floor();
        setState(() => _pos -= d.delta.dx / Turntable._pxPerFrame);
        if ((_pos / _quarter).floor() != before) HapticFeedback.selectionClick();
      },
      onHorizontalDragEnd: (_) => _release(),
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Image.asset(
          Turntable.frame(i),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          semanticLabel: 'Your Ioniq 6. Drag to turn it.',
        ),
      ),
    );
  }
}
