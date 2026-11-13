import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// Shows one of the Ioniq 6 Rive files and pushes [values] into its view
/// model by property name (see assets/rive/README.md for the contract).
/// Falls back to [fallback] when the native Rive runtime isn't available.
class RiveView extends StatefulWidget {
  const RiveView({
    super.key,
    required this.asset,
    required this.values,
    required this.fallback,
    this.artboard,
    this.fit = Fit.contain,
  });

  /// Off in widget tests, where the native runtime can't load.
  static bool enabled = true;

  final String asset;
  final String? artboard;
  final Map<String, Object> values;
  final Widget fallback;
  final Fit fit;

  @override
  State<RiveView> createState() => _RiveViewState();
}

class _RiveViewState extends State<RiveView> {
  late final FileLoader? _loader = RiveView.enabled
      ? FileLoader.fromAsset(widget.asset, riveFactory: Factory.rive)
      : null;

  @override
  void dispose() {
    _loader?.dispose();
    super.dispose();
  }

  void _push(ViewModelInstance? vm) {
    if (vm == null) return;
    for (final MapEntry(:key, :value) in widget.values.entries) {
      switch (value) {
        case bool b:
          vm.boolean(key)?.value = b;
        case num n:
          vm.number(key)?.value = n.toDouble();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loader = _loader;
    if (loader == null) return widget.fallback;
    return RiveWidgetBuilder(
      fileLoader: loader,
      artboardSelector: widget.artboard == null
          ? ArtboardSelector.byDefault()
          : ArtboardSelector.byName(widget.artboard!),
      dataBind: DataBind.auto(),
      builder: (context, state) => switch (state) {
        RiveLoaded(:final controller, :final viewModelInstance) => Builder(
          builder: (_) {
            _push(viewModelInstance);
            return RiveWidget(controller: controller, fit: widget.fit);
          },
        ),
        RiveFailed() => widget.fallback,
        RiveLoading() => const SizedBox.shrink(),
      },
    );
  }
}
