import 'package:flutter/material.dart';

import '../car/charge_schedule.dart';
import '../car/commands.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/hold_button.dart';
import '../widgets/line_icon.dart';

/// The car's charge schedule, with the off-peak window and mode editable
/// when car commands are on. Saving is a hold, like every car command.
class ChargeScheduleSheet extends StatefulWidget {
  const ChargeScheduleSheet({super.key, required this.schedule});
  final ChargeSchedule schedule;

  @override
  State<ChargeScheduleSheet> createState() => _ChargeScheduleSheetState();
}

class _ChargeScheduleSheetState extends State<ChargeScheduleSheet> {
  late OffPeakMode _mode = widget.schedule.mode;
  late int _start = widget.schedule.start, _end = widget.schedule.end;

  bool get _changed => _mode != widget.schedule.mode || _start != widget.schedule.start || _end != widget.schedule.end;

  static const _modeLabels = {
    OffPeakMode.off: 'Charge whenever plugged in',
    OffPeakMode.prefer: 'Prefer off-peak hours',
    OffPeakMode.only: 'Only charge off-peak',
  };

  Future<void> _pickTime(bool start) async {
    final now = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now ~/ 60, minute: now % 60),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    setState(() => start ? _start = picked.hour * 60 + picked.minute : _end = picked.hour * 60 + picked.minute);
  }

  Future<void> _save() async {
    await runCommand(context, SetOffPeakCommand(mode: _mode, start: _start, end: _end));
    // Only close the sheet if it's still open; it may have been dismissed meanwhile.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = widget.schedule;
    final canEdit = store.settings.commandsEnabled || store.isDemo;
    Widget line(String label, String value, {VoidCallback? onTap}) => ListTile(
      title: Text(label, style: Txt.body(16)),
      trailing: Text(value, style: onTap == null ? Txt.muted(16) : Txt.body(16)),
      onTap: onTap,
    );
    String departure(Departure d) {
      if (!d.enabled) return 'Off';
      final temp = d.tempC == null ? '' : ' ${store.settings.units.temp(d.tempC)}';
      return '${daySummary(d.days)} ${clock(d.minutes)}${d.climateOn ? ' · climate$temp' : ''}';
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Charge schedule', style: Txt.display(22, weight: 400)),
          ),
          if (canEdit)
            for (final mode in OffPeakMode.values)
              ListTile(
                title: Text(_modeLabels[mode]!, style: Txt.body(16)),
                subtitle: mode == OffPeakMode.prefer ? Text('Recommended by Hyundai', style: Txt.muted(14)) : null,
                trailing: mode == _mode ? const Icon(Icons.check, color: Palette.red) : null,
                onTap: () => setState(() => _mode = mode),
              )
          else
            line('Off-peak', _modeLabels[s.mode]!),
          line('Off-peak starts', clock(_start), onTap: canEdit ? () => _pickTime(true) : null),
          line('Off-peak ends', clock(_end), onTap: canEdit ? () => _pickTime(false) : null),
          line('Charge for departures', s.scheduledCharging ? 'On' : 'Off'),
          for (final (i, d) in s.departures.indexed) line('Departure ${i + 1}', departure(d)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: canEdit
                ? _SaveButton(enabled: _changed && store.pending == null, onHeld: _save)
                : Text(
                    'Turn on Car commands in Settings to change the off-peak window. Departure times stay as set in the car.',
                    style: Txt.muted(14),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled, required this.onHeld});
  final bool enabled;
  final VoidCallback onHeld;

  @override
  Widget build(BuildContext context) {
    final button = WideButton(
      icon: (color) => LineIcon(Glyphs.bolt, color: color, size: 22),
      label: AppScope.of(context).pending is SetOffPeakCommand ? 'Saving to the car…' : 'Hold to save to the car',
      onTap: null,
    );
    if (!enabled) return Opacity(opacity: .5, child: button);
    return HoldButton(
      onHeld: onHeld,
      builder: (context, p) => Stack(
        children: [
          button,
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: p,
                  child: ColoredBox(color: Palette.red.withValues(alpha: .18)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
