import 'package:flutter/material.dart';

import '../car/car_store.dart';
import '../theme.dart';

/// Makes the [CarStore] available below it and rebuilds dependents on change.
class AppScope extends InheritedNotifier<CarStore> {
  const AppScope({super.key, required CarStore store, required super.child}) : super(notifier: store);

  static CarStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// A screen with the mockup's back bar and a scrolling column, optionally
/// over a full-bleed [background].
class SubScreen extends StatelessWidget {
  const SubScreen({
    super.key,
    required this.title,
    required this.children,
    this.scroll = true,
    this.trailing,
    this.background,
    this.back = 'IONIQ 6',
  });

  final String title;

  /// The screen the back link returns to.
  final String back;
  final List<Widget> children;
  final bool scroll;
  final Widget? trailing;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gap(children, 14));
    final content = SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
            child: SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: TextButton.styleFrom(foregroundColor: Palette.mute),
                      child: Text('‹ $back', style: Txt.body(16, color: Palette.mute)),
                    ),
                  ),
                  // Never in the way of a tap on the back link.
                  IgnorePointer(child: Text(title, style: Txt.display(22, weight: 400))),
                  if (trailing != null) Align(alignment: Alignment.centerRight, child: trailing),
                ],
              ),
            ),
          ),
          Expanded(
            child: scroll
                ? ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [body])
                : Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: body),
          ),
        ],
      ),
    );
    final bg = background;
    return Scaffold(
      body: bg == null
          ? content
          : Stack(
              children: [
                Positioned.fill(child: bg),
                content,
              ],
            ),
    );
  }
}

List<Widget> _gap(List<Widget> items, double gap) => [
  for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: gap), items[i]],
];

class Panel extends StatelessWidget {
  const Panel({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14)});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Palette.raise, borderRadius: BorderRadius.circular(20)),
    padding: padding,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gap(children, 10)),
  );
}

class Kv extends StatelessWidget {
  const Kv(this.k, this.v, {super.key});
  final String k, v;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(flex: 3, child: Text(k, style: Txt.muted(15))),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: Text(
          v,
          textAlign: TextAlign.end,
          style: Txt.body(15, weight: 500).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ),
    ],
  );
}

class Lbl extends StatelessWidget {
  const Lbl(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: Txt.label());
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.text, {super.key, this.ok = true});
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: ok ? Palette.okDeep : const Color(0xFF33260F),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: Txt.body(14, color: ok ? Palette.ok : Palette.amber)),
  );
}

class NavRow extends StatelessWidget {
  const NavRow({super.key, this.icon, this.glyph, required this.label, this.sub, this.value, this.onTap});
  final IconData? icon;

  /// Drawn in place of [icon], for icons that aren't in the icon font.
  final Widget? glyph;
  final String label;
  final String? sub, value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          IconTheme(
            data: const IconThemeData(size: 20, color: Palette.mute),
            child: glyph ?? Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Txt.body(16)),
                if (sub != null) Text(sub!, style: Txt.muted(14)),
              ],
            ),
          ),
          if (value != null)
            Expanded(
              flex: 4,
              child: Text(
                value!,
                style: Txt.muted(14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: Palette.mute),
          ],
        ],
      ),
    ),
  );
}

/// The mockup's outlined full-width button with an icon (Defrost car, Take new
/// snapshot); red when [on].
class WideButton extends StatelessWidget {
  const WideButton({super.key, required this.icon, required this.label, this.on = false, required this.onTap});
  final Widget Function(Color color) icon;
  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: on ? Palette.red : const Color(0xFF3A3A3C)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          icon(on ? Palette.red : Palette.light),
          const SizedBox(width: 14),
          Flexible(child: Text(label, style: Txt.body(16), overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
  );
}

/// A row with a switch on the right, laid out like [NavRow].
class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, this.glyph, required this.label, this.sub, required this.value, this.onChanged});
  final Widget? glyph;
  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
    child: Row(
      children: [
        if (glyph != null) ...[
          IconTheme(
            data: const IconThemeData(size: 20, color: Palette.mute),
            child: glyph!,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Txt.body(16)),
              if (sub != null) Text(sub!, style: Txt.muted(14)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class RowsCard extends StatelessWidget {
  const RowsCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Material(
      color: Palette.raise,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: Palette.line),
            children[i],
          ],
        ],
      ),
    ),
  );
}

/// The 20-cell pixel bar used for state of charge.
class PixelBar extends StatelessWidget {
  const PixelBar({super.key, required this.pct, this.cells = 20, this.width = 120, this.limit, this.pulse = false});
  final int pct, cells;
  final double width;
  final int? limit;

  /// While charging, the next empty cell slowly pulses red.
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final lit = (pct / (100 / cells)).ceil();
    final lim = limit == null ? null : (limit! / (100 / cells)).ceil();
    return SizedBox(
      width: width,
      child: Row(
        children: [
          for (var i = 0; i < cells; i++)
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: pulse && i == lit && i < cells
                    ? const _PulseCell()
                    : Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: i < lit ? Palette.red : Palette.unlit,
                          borderRadius: BorderRadius.circular(1),
                          border: lim != null && i == lim - 1 && i >= lit ? Border.all(color: Palette.red) : null,
                          boxShadow: i < lit ? const [BoxShadow(color: Color(0x80E8333C), blurRadius: 5)] : null,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulseCell extends StatefulWidget {
  const _PulseCell();

  @override
  State<_PulseCell> createState() => _PulseCellState();
}

class _PulseCellState extends State<_PulseCell> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final t = Curves.easeInOutCubic.transform(_c.value);
      return Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: Color.lerp(Palette.unlit, Palette.red, t),
          borderRadius: BorderRadius.circular(1),
          boxShadow: [BoxShadow(color: Palette.red.withValues(alpha: .5 * t), blurRadius: 5)],
        ),
      );
    },
  );
}

String ago(DateTime? t) {
  if (t == null) return 'never';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String duration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

String thousands(int? n) =>
    n == null ? '–' : n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
