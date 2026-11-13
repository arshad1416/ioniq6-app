import 'package:flutter/material.dart';

/// Motion tokens, taken from the timings the Tesla app ships with: short UI
/// motion (100–250 ms), 250 ms screen changes and staggers, and slow motion
/// only for ambient things like counters.
abstract final class Motion {
  static const micro = Duration(milliseconds: 100); // slider magnify, small fades
  static const brief = Duration(milliseconds: 150); // hints shown during a gesture
  static const base = Duration(milliseconds: 200); // chevrons, snap-backs
  static const nav = Duration(milliseconds: 250); // screen changes, staggered entrances
  static const ambient = Duration(milliseconds: 800); // rolling numbers

  static const enter = Curves.easeInOutCubic;
  static const slider = Curves.easeInOutQuad;
  static const exit = Curves.easeOutQuad;
  static const decelerate = Cubic(.1, .7, .1, 1); // Material 3 emphasized decelerate

  /// Gap between items in a staggered entrance.
  static const stagger = Duration(milliseconds: 40);
}

/// Screen change: fade in while rising 8% of the screen, over 250 ms.
class FadeRiseRoute<T> extends PageRouteBuilder<T> {
  FadeRiseRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: Motion.nav,
        reverseTransitionDuration: Motion.nav,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          final t = CurvedAnimation(parent: animation, curve: Motion.decelerate, reverseCurve: Motion.exit);
          return FadeTransition(
            opacity: t,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .08), end: Offset.zero).animate(t),
              child: child,
            ),
          );
        },
      );
}

/// Fades and lifts [child] into place once, [index] steps after the first.
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.index, required this.child, this.distance = 40});
  final int index;
  final double distance;
  final Widget child;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.nav);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Motion.enter);

  @override
  void initState() {
    super.initState();
    Future.delayed(Motion.stagger * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _t.value,
      child: Transform.translate(offset: Offset(0, (1 - _t.value) * widget.distance), child: child),
    ),
  );
}

/// A number that rolls like an odometer when it changes: the old value slides
/// up and fades while the new one rises in 100 ms behind it, over 800 ms.
class RollingNumber extends StatefulWidget {
  const RollingNumber(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.ambient, value: 1);
  String? _old;

  @override
  void didUpdateWidget(RollingNumber old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _old = old.text;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final travel = (widget.style.fontSize ?? 14) * .9;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final out = Motion.enter.transform(_c.value);
        final into = Motion.enter.transform(const Interval(.125, 1).transform(_c.value));
        return ClipRect(
          child: Stack(
            children: [
              if (_old != null && _c.value < 1)
                Opacity(
                  opacity: 1 - out,
                  child: Transform.translate(
                    offset: Offset(0, -travel * out),
                    child: Text(_old!, style: widget.style),
                  ),
                ),
              Opacity(
                opacity: into,
                child: Transform.translate(
                  offset: Offset(0, travel * (1 - into)),
                  child: Text(widget.text, style: widget.style),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
