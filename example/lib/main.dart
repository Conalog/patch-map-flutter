import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';

void main() {
  runApp(const PatchmapExampleApp());
}

class PatchmapExampleApp extends StatelessWidget {
  const PatchmapExampleApp({super.key, this.initialElements});

  final List<Object?>? initialElements;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _PatchmapCanvas(initialElements: initialElements),
    );
  }
}

class _PatchmapCanvas extends StatefulWidget {
  const _PatchmapCanvas({this.initialElements});

  final List<Object?>? initialElements;

  @override
  State<_PatchmapCanvas> createState() => _PatchmapCanvasState();
}

class _PatchmapCanvasState extends State<_PatchmapCanvas> {
  static const String _targetPath = r'$..[?(@.id=="title")]';
  final Patchmap _patchmap = Patchmap();
  bool _didDraw = false;
  Map<String, Object?>? _selectedElement;

  Future<void> _handleReady(PatchmapRuntime _) async {
    if (_didDraw) {
      return;
    }
    try {
      final elements = widget.initialElements ?? await _loadDataFromAsset();
      _patchmap.draw(elements);
      _didDraw = true;
      _refreshSelectedElement();
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

  void _refreshSelectedElement() {
    final selected = _patchmap.selector(_targetPath);
    final next = selected.isEmpty ? null : _asJsonMapOrNull(selected.first);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedElement = next;
    });
  }

  void _updateTarget(Map<String, Object?> changes) {
    if (!_didDraw) {
      return;
    }
    _patchmap.update(
      options: PatchmapUpdateOptions(path: _targetPath, changes: changes),
    );
    _refreshSelectedElement();
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
    final selected = _selectedElement;
    final attrs =
        _asJsonMapOrNull(selected?['attrs']) ?? const <String, Object?>{};
    final style =
        _asJsonMapOrNull(selected?['style']) ?? const <String, Object?>{};
    final size = _asJsonMapOrNull(selected?['size']);
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
            child: PatchmapWidget(
              patchmap: _patchmap,
              options: const PatchmapInitOptions(
                app: PatchmapInitAppOptions(backgroundColor: Color(0xFFFFFFFF)),
              ),
              onReady: _handleReady,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ElevatedButton(
                key: const Key('btn-update-text'),
                onPressed: selected == null
                    ? null
                    : () => _updateTarget(const <String, Object?>{
                        'text': 'Updated title',
                      }),
                child: const Text('Update Text'),
              ),
              ElevatedButton(
                key: const Key('btn-update-label'),
                onPressed: selected == null
                    ? null
                    : () => _updateTarget(const <String, Object?>{
                        'label': 'updated-label',
                      }),
                child: const Text('Update Label'),
              ),
              ElevatedButton(
                key: const Key('btn-hide'),
                onPressed: selected == null
                    ? null
                    : () =>
                          _updateTarget(const <String, Object?>{'show': false}),
                child: const Text('Hide'),
              ),
              ElevatedButton(
                key: const Key('btn-show'),
                onPressed: selected == null
                    ? null
                    : () =>
                          _updateTarget(const <String, Object?>{'show': true}),
                child: const Text('Show'),
              ),
              ElevatedButton(
                key: const Key('btn-update-attrs'),
                onPressed: selected == null
                    ? null
                    : () => _updateTarget(const <String, Object?>{
                        'attrs': <String, Object?>{
                          'x': 120,
                          'y': 32,
                          'zIndex': 9,
                        },
                      }),
                child: const Text('Update Attrs'),
              ),
              ElevatedButton(
                key: const Key('btn-update-style'),
                onPressed: selected == null
                    ? null
                    : () => _updateTarget(const <String, Object?>{
                        'style': <String, Object?>{
                          'fontSize': 20,
                          'fill': 'red',
                        },
                      }),
                child: const Text('Update Style'),
              ),
              ElevatedButton(
                key: const Key('btn-update-size'),
                onPressed: selected == null
                    ? null
                    : () => _updateTarget(const <String, Object?>{
                        'size': <String, Object?>{'w': 300, 'h': 60},
                      }),
                child: const Text('Update Size'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('text=${_asStringOrNull(selected?['text']) ?? '-'}'),
          Text('label=${_asStringOrNull(selected?['label']) ?? '-'}'),
          Text('show=${_asBoolOrNull(selected?['show']) ?? '-'}'),
          Text(
            'attrs.x=${attrs['x'] ?? '-'} attrs.y=${attrs['y'] ?? '-'} attrs.zIndex=${attrs['zIndex'] ?? '-'}',
          ),
          Text(
            'style.fontSize=${style['fontSize'] ?? '-'} style.fill=${style['fill'] ?? '-'}',
          ),
          Text('size.w=${size?['w'] ?? '-'} size.h=${size?['h'] ?? '-'}'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Map<String, Object?>? _asJsonMapOrNull(Object? value) {
    if (value is! Map) {
      return null;
    }
    final out = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String) {
        out[key] = entry.value;
      }
    }
    return out;
  }

  static String? _asStringOrNull(Object? value) {
    return value is String ? value : null;
  }

  static bool? _asBoolOrNull(Object? value) {
    return value is bool ? value : null;
  }
}
