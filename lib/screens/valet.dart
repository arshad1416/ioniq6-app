import 'package:flutter/material.dart';

import '../car/commands.dart';
import '../car/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/hold_button.dart';
import '../widgets/line_icon.dart';

void _setInCar(BuildContext context) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(
    const SnackBar(content: Text('Bluelink Canada can only turn valet mode on and off. Change this in the car.')),
  );

/// Turns valet mode on or off with a hold. Needs the Ioniq 6 Extras add-on in
/// Home Assistant; until it's there the switch explains what's missing.
class ValetToggle extends StatelessWidget {
  const ValetToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final on = store.car.valetOn;
    if (on == null && !store.isDemo) {
      return GestureDetector(
        onTap: () => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Install the Ioniq 6 Extras add-on in Home Assistant to use valet mode.')),
          ),
        child: const Switch(value: false, onChanged: null),
      );
    }
    final value = on ?? false;
    return HoldButton(
      enabled: store.pending == null,
      onHeld: () => runCommand(context, ValetCommand(on: !value)),
      builder: (context, p) => Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Switch(value: value, onChanged: (_) {}),
          ),
          if (p > 0)
            SizedBox.square(
              dimension: 30,
              child: CircularProgressIndicator(value: p, strokeWidth: 2, color: Palette.red),
            ),
        ],
      ),
    );
  }
}

/// Valet settings. Bluelink Canada can only switch valet mode on and off;
/// the speed limit and the rest are set in the car, so they're shown here
/// (as the car reports them where it does) and kept on the phone.
class ValetScreen extends StatefulWidget {
  const ValetScreen({super.key});

  @override
  State<ValetScreen> createState() => _ValetScreenState();
}

class _ValetScreenState extends State<ValetScreen> {
  Future<void> _update(ValetPrefs Function(ValetPrefs v) change) async {
    final settings = AppScope.of(context).settings;
    setState(() => settings.valet = change(settings.valet));
    await settings.save();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final v = store.settings.valet;
    final carLimit = store.car.valetMaxSpeed;
    final limit = carLimit ?? v.speedLimitKmh;
    return SubScreen(
      title: 'Valet mode',
      back: 'Controls',
      children: [
        Panel(
          children: [
            Row(
              children: [
                Expanded(child: Text('Valet mode', style: Txt.body(16, weight: 600))),
                const ValetToggle(),
              ],
            ),
            Text('Hold the switch to turn it on or off. It uses your Bluelink PIN.', style: Txt.muted(13)),
          ],
        ),
        Panel(
          children: [
            Row(
              children: [
                Expanded(child: Text('Speed limit', style: Txt.body(16, weight: 600))),
                Text('$limit km/h', style: Txt.body(16, weight: 600)),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(overlayShape: SliderComponentShape.noOverlay),
              child: Slider(
                value: limit.clamp(40, 120).toDouble(),
                min: 40,
                max: 120,
                divisions: 8,
                onChanged: carLimit != null ? null : (x) => _update((v) => v.copyWith(speedLimitKmh: x.round())),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('40 km/h', style: Txt.muted(15)),
                Text('120 km/h', style: Txt.muted(15)),
              ],
            ),
            Text(
              carLimit != null
                  ? 'As set in the car. The car warns the valet and logs it if they go over.'
                  : 'The car warns the valet and logs it if they go over.',
              style: Txt.muted(13),
            ),
          ],
        ),
        Panel(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Valet PIN', style: Txt.body(16, weight: 600)),
                const SizedBox(width: 16),
                Expanded(child: Text('Needed to turn valet mode off', style: Txt.muted(15))),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: v.pinSet ? Palette.red : Palette.unlit),
                  ),
              ],
            ),
          ],
        ),
        RowsCard(
          children: [
            NavRow(glyph: const LineIcon(Glyphs.lock), label: 'Change valet PIN', onTap: () => _setInCar(context)),
            SwitchRow(
              glyph: const LineIcon(Glyphs.lines),
              label: 'Hide navigation history',
              sub: 'Recent places and saved addresses',
              value: v.hideNavigation,
              onChanged: (on) => _update((v) => v.copyWith(hideNavigation: on)),
            ),
            SwitchRow(
              glyph: const LineIcon(Glyphs.mail),
              label: 'Hide phone and messages',
              sub: 'Contacts, calls, texts on the screen',
              value: v.hidePhone,
              onChanged: (on) => _update((v) => v.copyWith(hidePhone: on)),
            ),
          ],
        ),
        Text(
          'Bluelink Canada can only turn valet mode on and off. Set the PIN and what\'s hidden in the car; '
          'these choices are kept on this phone as a reminder.',
          style: Txt.muted(13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
