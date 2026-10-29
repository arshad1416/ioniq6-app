import 'package:flutter/material.dart';

import '../car/commands.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/hold_button.dart';
import '../widgets/line_icon.dart';
import '../widgets/top_car.dart';

enum CameraView { front, rear, left, right, surround }

/// 360° camera shots, laid out as in the mockup. No camera source reaches Home
/// Assistant yet, so the viewer is empty and "Take new snapshot" (which would
/// wake the car) stays off.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const _sets = ['Latest', 'Parked', 'Walk-away'];
  int _set = 0;
  CameraView _view = CameraView.front;

  @override
  Widget build(BuildContext context) => SubScreen(
    title: '360 Camera',
    children: [
      Row(
        children: [
          for (var i = 0; i < _sets.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _Pill(_sets[i], on: i == _set, onTap: () => setState(() => _set = i)),
            ),
          ],
        ],
      ),
      _Viewer(view: _view, latestOnly: _set != 0),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 4, 14),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Center(
                child: _CarCams(view: _view, onPick: (v) => setState(() => _view = v)),
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final pair in const [
                    [CameraView.front, CameraView.rear],
                    [CameraView.left, CameraView.right],
                  ]) ...[
                    Row(
                      children: [
                        for (final v in pair) ...[
                          if (v != pair.first) const SizedBox(width: 6),
                          Expanded(
                            child: _Pill(_label(v), on: v == _view, onTap: () => setState(() => _view = v)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  _Pill(
                    'Surround (top view)',
                    on: _view == CameraView.surround,
                    onTap: () => setState(() => _view = CameraView.surround),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _TakeShots(),
      Text(
        AppScope.of(context).car.hasCamera || AppScope.of(context).isDemo
            ? 'Hold to ask the car for new shots. It wakes the car, and Bluelink limits how many you can take a day '
                  'and a month.'
            : 'Install the Ioniq 6 Extras add-on in Home Assistant to see the car\'s 360 shots.',
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

class _Pill extends StatelessWidget {
  const _Pill(this.label, {required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: Motion.base,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: on ? Palette.redDeep : Palette.raise, borderRadius: BorderRadius.circular(14)),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Txt.body(14, color: on ? Palette.red : Palette.mute),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

/// "Take new snapshot": a car command, so it's a hold, and only once the
/// add-on is there.
class _TakeShots extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final ready = store.car.hasCamera || store.isDemo;
    final button = WideButton(
      icon: (color) => LineIcon(Glyphs.camera, color: color, size: 22),
      label: store.pending is TakeCameraShotsCommand ? 'Asking the car…' : 'Take new snapshot',
      onTap: null,
    );
    if (!ready) return Opacity(opacity: .5, child: button);
    return HoldButton(
      enabled: store.pending == null,
      onHeld: () => runCommand(context, const TakeCameraShotsCommand()),
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

/// The 16:10 viewer: the car's latest shot for the chosen camera, or a dark
/// frame with parking guide lines (or the car from above for surround) until
/// there is one.
class _Viewer extends StatelessWidget {
  const _Viewer({required this.view, this.latestOnly = false});
  final CameraView view;

  /// Parked and Walk-away sets aren't kept yet; Bluelink only stores the latest.
  final bool latestOnly;

  static String _day(DateTime t) {
    final today = DateTime.now();
    final d = DateTime(t.year, t.month, t.day), now = DateTime(today.year, today.month, today.day);
    return switch (now.difference(d).inDays) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => '${t.day}/${t.month}',
    };
  }

  static String _entityView(CameraView v) => v == CameraView.surround ? 'top' : v.name;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final picture = latestOnly ? null : store.car.cameraPicture(_entityView(view));
    final url = picture == null ? null : store.haUri(picture);
    final taken = store.car.cameraTakenAt;
    final label = latestOnly
        ? 'Only the latest is kept'
        : url == null
        ? 'No shots yet'
        : taken == null
        ? 'Latest'
        : '${_day(taken)} ${hm(taken)}';
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, .2),
              radius: 1.1,
              colors: [Color(0xFF26282C), Color(0xFF0E0F11), Colors.black],
              stops: [0, .7, 1],
            ),
          ),
          child: Stack(
            children: [
              if (url != null)
                Positioned.fill(
                  child: Image.network(
                    url.toString(),
                    fit: view == CameraView.surround ? BoxFit.contain : BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stack) => const CustomPaint(painter: _GuidePainter()),
                  ),
                )
              else if (view == CameraView.surround)
                const Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Image(image: AssetImage(TopCar.asset), fit: BoxFit.contain),
                  ),
                )
              else
                const Positioned.fill(child: CustomPaint(painter: _GuidePainter())),
              Positioned(
                left: 12,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                  child: Text(_CameraScreenState._label(view), style: Txt.body(14, weight: 600)),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 10,
                child: Text(label, style: Txt.mono(12, weight: 400, color: const Color(0xFFCFCFD2))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The car from above with a dot at each camera; tap one to pick it.
class _CarCams extends StatelessWidget {
  const _CarCams({required this.view, required this.onPick});
  final CameraView view;
  final ValueChanged<CameraView> onPick;

  static const _height = 220.0;

  @override
  Widget build(BuildContext context) {
    bool on(CameraView v) => view == v || view == CameraView.surround;
    CarSpot dot(Offset at, CameraView v) => CarSpot(
      at,
      const Size.square(32),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onPick(v),
        child: Center(
          child: AnimatedContainer(
            duration: Motion.base,
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on(v) ? Palette.red : Palette.unlit,
              border: Border.all(color: Palette.stage, width: 2),
              boxShadow: on(v) ? [BoxShadow(color: Palette.red.withValues(alpha: .7), blurRadius: 8)] : null,
            ),
          ),
        ),
      ),
    );
    return TopCar(
      height: _height,
      spots: [
        dot(const Offset(.467, -.04), CameraView.front),
        dot(const Offset(.467, 1.04), CameraView.rear),
        dot(const Offset(-.14, .42), CameraView.left),
        dot(const Offset(1.08, .42), CameraView.right),
      ],
    );
  }
}

/// The mockup's guide: amber side lines converging, with two red distance bars,
/// drawn in a 160×100 box stretched to the viewer.
class _GuidePainter extends CustomPainter {
  const _GuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 160, size.height / 100);
    Paint pen(Color c) => Paint()
      ..color = c
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final amber = pen(const Color(0x99FFB02E)), red = pen(const Color(0x8CE8333C));
    canvas
      ..drawLine(const Offset(40, 100), const Offset(58, 52), amber)
      ..drawLine(const Offset(120, 100), const Offset(102, 52), amber)
      ..drawLine(const Offset(47, 82), const Offset(113, 82), red)
      ..drawLine(const Offset(53, 66), const Offset(107, 66), red);
  }

  @override
  bool shouldRepaint(_GuidePainter old) => false;
}
