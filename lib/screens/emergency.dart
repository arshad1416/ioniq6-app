import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';

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
      back: 'Settings',
      children: [
        // Opens the phone's dialer with 911 filled in; the call is placed there.
        FilledButton(
          onPressed: () => _dial('911'),
          style: FilledButton.styleFrom(
            backgroundColor: Palette.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: Txt.body(19, weight: 600),
          ),
          child: const Text('Call 911'),
        ),
        RowsCard(
          children: [
            NavRow(
              glyph: const LineIcon(Glyphs.tow),
              label: 'Roadside assistance',
              sub: 'Tow, flat tire, battery, lockout · $roadsideNumber',
              onTap: () => _dial(roadsideNumber),
            ),
            NavRow(
              glyph: const LineIcon(Glyphs.warning),
              label: 'Report a collision',
              sub: 'Photos, location, other driver',
              value: 'Coming soon',
            ),
            NavRow(
              glyph: const LineIcon(Glyphs.pinFilled),
              label: 'Share car location',
              sub: loc == null ? 'The car isn\'t sharing its location right now' : 'Send where the car is to a contact',
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
          'The car\'s own SOS button connects to Bluelink\'s emergency line. Call 911 and Roadside open your '
          'phone\'s dialer; nothing is called until you press call there.',
          style: Txt.muted(13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
