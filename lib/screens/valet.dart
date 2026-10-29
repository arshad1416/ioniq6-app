import 'package:flutter/material.dart';

import '../car/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';

void valetComingSoon(BuildContext context) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(
    const SnackBar(content: Text('Valet mode needs Bluelink features Home Assistant doesn\'t have yet. It\'s coming.')),
  );

/// Valet settings: speed limit, valet PIN and what's hidden from the valet.
/// They're kept on the phone for now; the car only gets them once Home
/// Assistant can reach Bluelink's valet settings.
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
    final v = AppScope.of(context).settings.valet;
    return SubScreen(
      title: 'Valet mode',
      back: 'Controls',
      children: [
        Panel(
          children: [
            Row(
              children: [
                Expanded(child: Text('Speed limit', style: Txt.body(16, weight: 600))),
                Text('${v.speedLimitKmh} km/h', style: Txt.body(16, weight: 600)),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(overlayShape: SliderComponentShape.noOverlay),
              child: Slider(
                value: v.speedLimitKmh.toDouble(),
                min: 40,
                max: 120,
                divisions: 8,
                onChanged: (x) => _update((v) => v.copyWith(speedLimitKmh: x.round())),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('40 km/h', style: Txt.muted(15)),
                Text('120 km/h', style: Txt.muted(15)),
              ],
            ),
            Text('The car warns the valet and logs it if they go over.', style: Txt.muted(13)),
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
            NavRow(
              glyph: const LineIcon(Glyphs.lock),
              label: 'Change valet PIN',
              onTap: () => valetComingSoon(context),
            ),
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
          'Saved on this phone for now. Sending these to the car needs Bluelink\'s valet settings in Home Assistant, '
          'and will then ask for a hold and your PIN.',
          style: Txt.muted(13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
