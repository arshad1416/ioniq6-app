import 'package:flutter/material.dart';

import '../car/car_state.dart';
import '../car/car_store.dart';
import '../car/commands.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/hold_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final car = store.car;
    final soc = car.soc ?? 0;
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
                  Text('${car.rangeKm ?? '–'}', style: Txt.display(34)),
                  Text(' km', style: Txt.display(15)),
                  const SizedBox(width: 12),
                  Flexible(child: PixelBar(pct: soc)),
                  const SizedBox(width: 12),
                  Text('$soc%', style: Txt.display(15)),
                  if (car.charging) const Icon(Icons.bolt, color: Palette.red, size: 18),
                ],
              ),
              _Hero(onTap: () => Navigator.pushNamed(context, '/controls')),
              _QuickActions(store: store),
              const SizedBox(height: 14),
              RowsCard(
                children: [
                  NavRow(
                    icon: Icons.directions_car_outlined,
                    label: 'Controls',
                    value: car.allClosed ? _lockWord(store.lockState) : 'Something is open',
                    onTap: () => Navigator.pushNamed(context, '/controls'),
                  ),
                  NavRow(
                    icon: Icons.thermostat_outlined,
                    label: 'Climate',
                    value: car.climateOn ? 'On · ${_t(car.setTempC)}' : 'Off · set ${_t(store.settings.climate.tempC)}',
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
                    value: '${thousands(car.odometerKm)} km',
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

String _t(double? c) => c == null ? '–' : '${c.toStringAsFixed(c % 1 == 0 ? 0 : 1)}°';

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
          Hero(
            tag: 'car',
            child: Image.asset('assets/images/car.webp', fit: BoxFit.contain, semanticLabel: 'Your Ioniq 6'),
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
            icon: Icons.ac_unit,
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
  const _Qa({required this.icon, required this.label, this.on = false, this.onTap, this.progress = 0});
  final IconData icon;
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
              child: Icon(icon, color: color, size: 24),
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
