import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';

void main() {
  runApp(const PatchmapExampleApp());
}

class PatchmapExampleApp extends StatelessWidget {
  const PatchmapExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patchmap Runtime Example',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Patchmap Runtime Example')),
        body: const _PatchmapCanvas(),
      ),
    );
  }
}

class _PatchmapCanvas extends StatelessWidget {
  const _PatchmapCanvas();

  static const List<String> _iconAliases = <String>[
    'object',
    'inverter',
    'combiner',
    'device',
    'edge',
    'loading',
    'downloaded-bolt',
  ];

  static final TextPaint _titlePaint = TextPaint(
    style: const TextStyle(
      fontFamily: 'FiraCode',
      package: 'patch_map_flutter',
      fontWeight: FontWeight.w100,
      fontSize: 22,
      color: Colors.red,
    ),
  );

  static final TextPaint _labelPaint = TextPaint(
    style: const TextStyle(
      fontFamily: 'FiraCode',
      package: 'patch_map_flutter',
      fontWeight: FontWeight.w400,
      fontSize: 13,
      color: Colors.black87,
    ),
  );

  void _handleReady(PatchmapRuntime runtime) {
    unawaited(_buildScene(runtime));
  }

  Future<void> _buildScene(PatchmapRuntime game) async {
    try {
      game.add(
        TextComponent(
          text: 'SVG icons + FiraCode text from patch_map_flutter 0123456789',
          position: Vector2(24, 24),
          textRenderer: _titlePaint,
        ),
      );

      final spriteByAlias = await game.iconSprites(_iconAliases, edgePx: 96);

      game.add(
        TextComponent(
          text: 'SpriteComponent (shared sprite cache) x 120',
          position: Vector2(24, 56),
          textRenderer: _labelPaint,
        ),
      );

      const iconSize = 40.0;
      const colCount = 12;
      const rowCount = 10;
      const startX = 20.0;
      const startY = 84.0;
      const xGap = 52.0;
      const yGap = 52.0;

      var index = 0;
      for (var row = 0; row < rowCount; row++) {
        for (var col = 0; col < colCount; col++) {
          final alias = _iconAliases[index % _iconAliases.length];
          final sprite = spriteByAlias[alias];
          if (sprite == null) {
            index++;
            continue;
          }

          game.add(
            SpriteComponent(
              sprite: sprite,
              size: Vector2.all(iconSize),
              position: Vector2(startX + (xGap * col), startY + (yGap * row)),
              paint: Paint()
                ..colorFilter = const ColorFilter.mode(
                  Colors.black26,
                  BlendMode.srcIn,
                ),
            ),
          );
          index++;
        }
      }

      game.add(
        TextComponent(
          text: 'Font sample: FiraCode SemiBold 18',
          position: Vector2(24, startY + (yGap * rowCount) + 12),
          textRenderer: TextPaint(
            style: const TextStyle(
              fontFamily: 'FiraCode',
              package: 'patch_map_flutter',
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ),
      );

      game.add(
        TextComponent(
          text: '0123456789  {patch-map}  icons rendered via SpriteComponent',
          position: Vector2(24, startY + (yGap * rowCount) + 40),
          textRenderer: _labelPaint,
        ),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'patch_map_flutter_example',
          context: ErrorDescription('while building Patchmap example scene'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PatchmapWidget(
      options: const PatchmapInitOptions(
        app: PatchmapInitAppOptions(backgroundColor: Color(0xFFFFFFFF)),
        assets: PatchmapInitAssets(
          iconAssetPathByAlias: <String, String>{
            'downloaded-bolt': 'assets/icons/downloaded-bolt.svg',
          },
        ),
      ),
      onReady: _handleReady,
    );
  }
}
