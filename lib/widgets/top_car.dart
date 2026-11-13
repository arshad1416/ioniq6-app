import 'package:flutter/material.dart';

/// Something laid on the overhead car: its centre as fractions of the car's
/// box, and its size in logical pixels.
class CarSpot {
  const CarSpot(this.at, this.size, this.child) : area = null;

  /// Covers [area] of the car's box, given as fractions.
  const CarSpot.area(Rect this.area, this.child) : at = Offset.zero, size = Size.zero;

  final Offset at;
  final Size size;
  final Rect? area;
  final Widget child;
}

/// Arshad's car from above (the mockup's `topdown.webp` cutout), at a fixed
/// height like the mockup's Controls and Climate screens, with [spots] placed
/// on it by fraction so they stay on the sunroof, seats and spoiler.
class TopCar extends StatelessWidget {
  const TopCar({super.key, required this.height, this.spots = const [], this.behind = const []});

  static const asset = 'assets/images/topdown.webp';
  static const aspect = 460 / 906;

  final double height;
  final List<CarSpot> spots;

  /// Spots drawn under the photo, such as a glow.
  final List<CarSpot> behind;

  @override
  Widget build(BuildContext context) {
    final size = Size(height * aspect, height);
    Widget place(CarSpot s) => s.area != null
        ? Positioned.fromRect(
            rect: Rect.fromLTRB(
              s.area!.left * size.width,
              s.area!.top * size.height,
              s.area!.right * size.width,
              s.area!.bottom * size.height,
            ),
            child: s.child,
          )
        : Positioned(
            left: s.at.dx * size.width - s.size.width / 2,
            top: s.at.dy * size.height - s.size.height / 2,
            width: s.size.width,
            height: s.size.height,
            child: s.child,
          );
    // The car sits a little left of centre in the cutout; the mockup nudges it.
    return Transform.translate(
      offset: Offset(size.width * .033, 0),
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ...behind.map(place),
            Positioned.fill(
              child: Hero(
                tag: 'car',
                child: Image.asset(asset, fit: BoxFit.fill, semanticLabel: 'Your Ioniq 6 from above'),
              ),
            ),
            ...spots.map(place),
          ],
        ),
      ),
    );
  }
}
