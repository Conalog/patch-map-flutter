import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../patch_map.dart';

typedef PatchmapRuntimeWidgetBuilder =
    Widget Function(BuildContext context, PatchmapRuntime runtime);

typedef PatchmapErrorWidgetBuilder =
    Widget Function(BuildContext context, Object error, StackTrace? stackTrace);

class PatchmapWidget extends StatefulWidget {
  const PatchmapWidget({
    super.key,
    this.patchmap,
    this.options = const PatchmapInitOptions(),
    this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.onReady,
  });

  final Patchmap? patchmap;
  final PatchmapInitOptions options;
  final PatchmapRuntimeWidgetBuilder? builder;
  final WidgetBuilder? loadingBuilder;
  final PatchmapErrorWidgetBuilder? errorBuilder;
  final ValueChanged<PatchmapRuntime>? onReady;

  @override
  State<PatchmapWidget> createState() => _PatchmapWidgetState();
}

class _PatchmapWidgetState extends State<PatchmapWidget> {
  late Patchmap _patchmap;
  late Future<PatchmapRuntime> _runtimeFuture;
  final Set<PatchmapRuntime> _readyNotifiedRuntimes = <PatchmapRuntime>{};

  @override
  void initState() {
    super.initState();
    _bindPatchmap(widget.patchmap);
  }

  @override
  void didUpdateWidget(covariant PatchmapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.patchmap != widget.patchmap ||
        oldWidget.options != widget.options) {
      _bindPatchmap(widget.patchmap);
      setState(() {});
    }
  }

  void _bindPatchmap(Patchmap? patchmap) {
    _patchmap = patchmap ?? Patchmap();
    _runtimeFuture = _initializeRuntime();
  }

  Future<PatchmapRuntime> _initializeRuntime() async {
    await _patchmap.init(options: widget.options);
    final runtime = _patchmap.app;
    if (_readyNotifiedRuntimes.add(runtime)) {
      widget.onReady?.call(runtime);
    }
    return runtime;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PatchmapRuntime>(
      future: _runtimeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          final loadingBuilder = widget.loadingBuilder;
          return loadingBuilder?.call(context) ??
              Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final errorBuilder = widget.errorBuilder;
          final error = snapshot.error!;
          return errorBuilder?.call(context, error, snapshot.stackTrace) ??
              Center(child: Text('Failed to initialize: $error'));
        }

        final runtime = snapshot.requireData;
        final readyBuilder = widget.builder ?? _defaultBuilder;
        return readyBuilder(context, runtime);
      },
    );
  }

  static Widget _defaultBuilder(BuildContext context, PatchmapRuntime runtime) {
    return GameWidget(game: runtime);
  }
}
