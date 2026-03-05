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
  static const String _targetTextPath = r'$..[?(@.id=="title")]';
  static const String _targetImagePath = r'$..[?(@.id=="status-image")]';
  final Patchmap _patchmap = Patchmap();
  bool _didDraw = false;
  Map<String, Object?>? _selectedTextElement;
  Map<String, Object?>? _selectedImageElement;

  Future<void> _handleReady(PatchmapRuntime _) async {
    if (_didDraw) {
      return;
    }
    try {
      final elements = widget.initialElements ?? await _loadDataFromAsset();
      _patchmap.draw(elements);
      _didDraw = true;
      _refreshSelectedElements();
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

  void _refreshSelectedElements() {
    final selectedText = _patchmap.selector(_targetTextPath);
    final selectedImage = _patchmap.selector(_targetImagePath);
    final nextText = selectedText.isEmpty
        ? null
        : _asJsonMapOrNull(selectedText.first);
    final nextImage = selectedImage.isEmpty
        ? null
        : _asJsonMapOrNull(selectedImage.first);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTextElement = nextText;
      _selectedImageElement = nextImage;
    });
  }

  void _updateTextTarget(Map<String, Object?> changes) {
    _updateTarget(path: _targetTextPath, changes: changes);
  }

  void _updateImageTarget(Map<String, Object?> changes) {
    _updateTarget(path: _targetImagePath, changes: changes);
  }

  void _updateTarget({
    required String path,
    required Map<String, Object?> changes,
  }) {
    if (!_didDraw) {
      return;
    }
    _patchmap.update(
      options: PatchmapUpdateOptions(path: path, changes: changes),
    );
    _refreshSelectedElements();
  }

  Future<List<Object?>> _loadDataFromAsset() async {
    final jsonString = await rootBundle.loadString('assets/data.json');
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      throw const FormatException('assets/data.json root must be a JSON array');
    }
    return decoded.cast<Object?>();
  }

  Object? _sizeValue(
    Map<String, Object?>? size,
    String shortKey,
    String longKey,
  ) {
    if (size == null) {
      return null;
    }
    return size[shortKey] ?? size[longKey];
  }

  @override
  Widget build(BuildContext context) {
    final selectedText = _selectedTextElement;
    final textAttrs =
        _asJsonMapOrNull(selectedText?['attrs']) ?? const <String, Object?>{};
    final textStyle =
        _asJsonMapOrNull(selectedText?['style']) ?? const <String, Object?>{};
    final textSize = _asJsonMapOrNull(selectedText?['size']);
    final selectedImage = _selectedImageElement;
    final imageAttrs =
        _asJsonMapOrNull(selectedImage?['attrs']) ?? const <String, Object?>{};
    final imageSize = _asJsonMapOrNull(selectedImage?['size']);
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
                onPressed: selectedText == null
                    ? null
                    : () => _updateTextTarget(const <String, Object?>{
                        'text': 'Updated title',
                      }),
                child: const Text('Update Text'),
              ),
              ElevatedButton(
                key: const Key('btn-update-label'),
                onPressed: selectedText == null
                    ? null
                    : () => _updateTextTarget(const <String, Object?>{
                        'label': 'updated-label',
                      }),
                child: const Text('Update Label'),
              ),
              ElevatedButton(
                key: const Key('btn-hide'),
                onPressed: selectedText == null
                    ? null
                    : () => _updateTextTarget(const <String, Object?>{
                        'show': false,
                      }),
                child: const Text('Hide'),
              ),
              ElevatedButton(
                key: const Key('btn-show'),
                onPressed: selectedText == null
                    ? null
                    : () => _updateTextTarget(const <String, Object?>{
                        'show': true,
                      }),
                child: const Text('Show'),
              ),
              ElevatedButton(
                key: const Key('btn-update-attrs'),
                onPressed: selectedText == null
                    ? null
                    : () => _updateTextTarget(const <String, Object?>{
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
                onPressed: selectedText == null
                    ? null
                    : () => _updateTextTarget(const <String, Object?>{
                        'style': <String, Object?>{
                          'fontSize': 20,
                          'fill': 'red',
                        },
                      }),
                child: const Text('Update Style'),
              ),
              ElevatedButton(
                key: const Key('btn-update-size'),
                onPressed: selectedText == null
                    ? null
                    : () => _updateTextTarget(const <String, Object?>{
                        'size': <String, Object?>{'w': 300, 'h': 60},
                      }),
                child: const Text('Update Size'),
              ),
              ElevatedButton(
                key: const Key('btn-image-warning'),
                onPressed: selectedImage == null
                    ? null
                    : () => _updateImageTarget(const <String, Object?>{
                        'source': 'warning',
                      }),
                child: const Text('Image Warning'),
              ),
              ElevatedButton(
                key: const Key('btn-image-size'),
                onPressed: selectedImage == null
                    ? null
                    : () => _updateImageTarget(const <String, Object?>{
                        'size': <String, Object?>{'w': 72, 'h': 72},
                      }),
                child: const Text('Image Size'),
              ),
              ElevatedButton(
                key: const Key('btn-image-move'),
                onPressed: selectedImage == null
                    ? null
                    : () => _updateImageTarget(const <String, Object?>{
                        'attrs': <String, Object?>{
                          'x': 180,
                          'y': 140,
                          'zIndex': 5,
                        },
                      }),
                child: const Text('Image Move'),
              ),
              ElevatedButton(
                key: const Key('btn-image-tint'),
                onPressed: selectedImage == null
                    ? null
                    : () => _updateImageTarget(const <String, Object?>{
                        'tint': '#ff0000',
                      }),
                child: const Text('Image Tint'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('text=${_asStringOrNull(selectedText?['text']) ?? '-'}'),
          Text('label=${_asStringOrNull(selectedText?['label']) ?? '-'}'),
          Text('show=${_asBoolOrNull(selectedText?['show']) ?? '-'}'),
          Text(
            'attrs.x=${textAttrs['x'] ?? '-'} attrs.y=${textAttrs['y'] ?? '-'} attrs.zIndex=${textAttrs['zIndex'] ?? '-'}',
          ),
          Text(
            'style.fontSize=${textStyle['fontSize'] ?? '-'} style.fill=${textStyle['fill'] ?? '-'}',
          ),
          Text(
            'size.w=${_sizeValue(textSize, 'w', 'width') ?? '-'} size.h=${_sizeValue(textSize, 'h', 'height') ?? '-'}',
          ),
          const SizedBox(height: 12),
          Text(
            'image.source=${_asStringOrNull(selectedImage?['source']) ?? '-'}',
          ),
          Text('image.tint=${selectedImage?['tint'] ?? '-'}'),
          Text(
            'image.size.w=${_sizeValue(imageSize, 'w', 'width') ?? '-'} image.size.h=${_sizeValue(imageSize, 'h', 'height') ?? '-'}',
          ),
          Text(
            'image.attrs.x=${imageAttrs['x'] ?? '-'} image.attrs.y=${imageAttrs['y'] ?? '-'} image.attrs.zIndex=${imageAttrs['zIndex'] ?? '-'}',
          ),
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
