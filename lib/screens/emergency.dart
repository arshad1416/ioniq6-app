import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Hyundai Canada roadside assistance, open 24/7.
const roadsideNumber = '1-800-268-9958';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  Future<void> _dial(String number) => launchUrl(Uri(scheme: 'tel', path: number.replaceAll('-', '')));

  @override
  Widget build(BuildContext context) {
    final car = AppScope.of(context).car;
    final loc = car.location;
    return SubScreen(
      title: 'Emergency',
      children: [
        // Opens the phone's dialer with 911 filled in; the call is placed there.
        FilledButton.icon(
          onPressed: () => _dial('911'),
          icon: const Icon(Icons.call),
          label: const Text('Call 911'),
          style: FilledButton.styleFrom(
            backgroundColor: Palette.red,
            padding: const EdgeInsets.symmetric(vertical: 18),
            textStyle: Txt.body(19, weight: 600),
          ),
        ),
        RowsCard(
          children: [
            NavRow(
              icon: Icons.car_repair,
              label: 'Roadside assistance',
              sub: 'Hyundai Canada, 24/7: $roadsideNumber',
              onTap: () => _dial(roadsideNumber),
            ),
            NavRow(
              icon: Icons.car_crash_outlined,
              label: 'Report a collision',
              sub: 'Needs Bluelink features Home Assistant doesn\'t have yet',
              value: 'Coming soon',
            ),
            NavRow(
              icon: Icons.share_location,
              label: 'Share car location',
              sub: loc == null ? 'The car isn\'t sharing its location right now' : 'Send a map link',
              onTap: loc == null
                  ? null
                  : () => SharePlus.instance.share(
                      ShareParams(
                        text: 'My IONIQ 6 is here: https://maps.google.com/?q=${loc.$1},${loc.$2}',
                        subject: 'Car location',
                      ),
                    ),
            ),
          ],
        ),
        Text(
          'Call 911 and Roadside open your phone\'s dialer. Nothing is called until you press call there.',
          style: Txt.muted(13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
