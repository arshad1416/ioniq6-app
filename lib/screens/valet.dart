import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

void valetComingSoon(BuildContext context) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(
    const SnackBar(content: Text('Valet mode needs Bluelink features Home Assistant doesn\'t have yet. It\'s coming.')),
  );

/// Valet settings: speed limit, valet PIN and what's hidden from the valet.
/// These are saved in the car through Bluelink, which Home Assistant can't
/// reach yet, so everything here is shown but locked.
class ValetScreen extends StatelessWidget {
  const ValetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = AppScope.of(context).settings.valet;
    Widget locked(String title, bool value) => Opacity(
      opacity: .5,
      child: SwitchListTile(
        title: Text(title, style: Txt.body(16)),
        value: value,
        onChanged: null,
      ),
    );
    return SubScreen(
      title: 'Valet mode',
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Palette.redDeep, borderRadius: BorderRadius.circular(14)),
          child: Text(
            'These settings are saved in the car through Bluelink. Home Assistant can\'t do that yet, so they\'re locked for now.',
            style: Txt.body(15),
          ),
        ),
        Panel(
          children: [
            Row(
              children: [
                Expanded(child: Text('Speed limit', style: Txt.body(16, weight: 500))),
                Text('${v.speedLimitKmh} km/h', style: Txt.body(16, weight: 500, color: Palette.red)),
              ],
            ),
            Slider(
              value: v.speedLimitKmh.toDouble(),
              min: 40,
              max: 120,
              divisions: 8,
              label: '${v.speedLimitKmh} km/h',
              onChanged: null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('40', style: Txt.muted(13)),
                Text('120 km/h', style: Txt.muted(13)),
              ],
            ),
          ],
        ),
        RowsCard(
          children: [
            NavRow(icon: Icons.pin_outlined, label: 'Valet PIN', value: v.pinSet ? '● ● ● ●' : 'Not set'),
            NavRow(
              icon: Icons.password,
              label: 'Change valet PIN',
              sub: 'Old PIN, then the new one twice',
              value: 'Coming soon',
              onTap: () => valetComingSoon(context),
            ),
          ],
        ),
        RowsCard(
          children: [
            locked('Hide navigation history', v.hideNavigation),
            locked('Hide phone and messages', v.hidePhone),
          ],
        ),
      ],
    );
  }
}
