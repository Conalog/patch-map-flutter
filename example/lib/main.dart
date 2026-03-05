import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';

void main() {
  runApp(const PatchmapExampleApp());
}

class PatchmapExampleApp extends StatelessWidget {
  const PatchmapExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const _PatchmapCanvas(),
    );
  }
}

class _PatchmapCanvas extends StatefulWidget {
  const _PatchmapCanvas();

  @override
  State<_PatchmapCanvas> createState() => _PatchmapCanvasState();
}

class _PatchmapCanvasState extends State<_PatchmapCanvas> {
  final Patchmap _patchmap = Patchmap();
  bool _didDraw = false;

  Future<void> _handleReady(PatchmapRuntime _) async {
    if (_didDraw) {
      return;
    }
    try {
      final elements = await _loadDataFromAsset();
      _patchmap.draw(elements);
      _didDraw = true;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'patch_map_flutter_example',
          context: ErrorDescription(
            'while loading assets/data.json and draw()',
          ),
        ),
      );
    }
  }

  Future<List<Object?>> _loadDataFromAsset() async {
    final jsonString = await rootBundle.loadString('assets/data.json');
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      throw const FormatException('assets/data.json root must be a JSON array');
    }
    return decoded.cast<Object?>();
  }

  @override
  Widget build(BuildContext context) {
    return PatchmapWidget(
      patchmap: _patchmap,
      options: const PatchmapInitOptions(
        app: PatchmapInitAppOptions(backgroundColor: Color(0xFFFFFFFF)),
      ),
      onReady: _handleReady,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
