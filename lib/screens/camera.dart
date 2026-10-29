import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum CameraView { front, rear, left, right, surround }

/// 360° camera shots. No camera source reaches Home Assistant yet, so this
/// shows an empty viewer and keeps "Take new snapshot" off until one does.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const _tabs = ['Latest', 'Parked', 'Walk-away'];
  int _tab = 0;
  CameraView _view = CameraView.surround;

  @override
  Widget build(BuildContext context) => SubScreen(
    title: '360 Camera',
    children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Palette.raise, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.enter,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: i == _tab ? Palette.unlit : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      _tabs[i],
                      textAlign: TextAlign.center,
                      style: Txt.body(15, weight: 500, color: i == _tab ? Palette.ink : Palette.mute),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      AspectRatio(
        aspectRatio: 16 / 10,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF0E0E10)),
            child: Stack(
              children: [
                const Positioned.fill(child: CustomPaint(painter: _GuidePainter())),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_camera_outlined, color: Palette.mute, size: 30),
                      const SizedBox(height: 8),
                      Text('No ${_tabs[_tab].toLowerCase()} shots yet', style: Txt.body(16)),
                      const SizedBox(height: 4),
                      Text('${_label(_view)} view', style: Txt.muted(14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Row(
        children: [
          SizedBox(width: 92, height: 150, child: _CarCams(view: _view)),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in CameraView.values)
                  ChoiceChip(
                    label: Text(_label(v)),
                    selected: v == _view,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _view = v),
                    selectedColor: Palette.redDeep,
                    backgroundColor: Palette.raise,
                    side: BorderSide(color: v == _view ? Palette.red : Palette.line),
                    labelStyle: Txt.body(15, color: v == _view ? Palette.ink : Palette.light),
                  ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Take new snapshot'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      ),
      Text(
        'Snapshots need a camera source in Home Assistant. This turns on once one is connected.',
        style: Txt.muted(13),
        textAlign: TextAlign.center,
      ),
    ],
  );

  static String _label(CameraView v) => switch (v) {
    CameraView.front => 'Front',
    CameraView.rear => 'Rear',
    CameraView.left => 'Left',
    CameraView.right => 'Right',
    CameraView.surround => 'Surround',
  };
}

/// The car from above with a dot at each camera; the selected ones light red.
class _CarCams extends StatelessWidget {
  const _CarCams({required this.view});
  final CameraView view;

  @override
  Widget build(BuildContext context) {
    bool on(CameraView v) => view == v || view == CameraView.surround;
    Widget dot(Alignment a, CameraView v) => Align(
      alignment: a,
      child: AnimatedContainer(
        duration: Motion.base,
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on(v) ? Palette.red : Palette.unlit,
          border: Border.all(color: Palette.stage, width: 2),
          boxShadow: on(v) ? [BoxShadow(color: Palette.red.withValues(alpha: .6), blurRadius: 6)] : null,
        ),
      ),
    );
    return Stack(
      children: [
        Center(
          child: RotatedBox(quarterTurns: 1, child: Image.asset('assets/images/top.webp', fit: BoxFit.contain)),
        ),
        dot(const Alignment(0, -.92), CameraView.front),
        dot(const Alignment(0, .92), CameraView.rear),
        dot(const Alignment(-.62, -.2), CameraView.left),
        dot(const Alignment(.62, -.2), CameraView.right),
      ],
    );
  }
}

/// Parking guide lines: two converging side lines with distance ticks.
class _GuidePainter extends CustomPainter {
  const _GuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final colors = [const Color(0xFFE8333C), const Color(0xFFFFB02E), const Color(0xFF7FD67A)];
    for (var i = 0; i < 3; i++) {
      final paint = Paint()
        ..color = colors[i].withValues(alpha: .45)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final y0 = h * (1 - i * .22), y1 = h * (1 - (i + 1) * .22);
      double x(double y, bool left) {
        final t = (h - y) / h; // 0 at bottom, 1 at top
        final inset = w * (.12 + .2 * t);
        return left ? inset : w - inset;
      }

      for (final left in [true, false]) {
        canvas.drawLine(Offset(x(y0, left), y0), Offset(x(y1, left), y1), paint);
        canvas.drawLine(Offset(x(y1, left), y1), Offset(x(y1, left) + (left ? 14 : -14), y1), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) => false;
}
