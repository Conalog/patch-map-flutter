import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';
import 'package:patch_map_flutter/src/runtime/patchmap_asset_registry.dart';

import '../helpers/widget_pump.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'calls onReady only for latest bind after rapid patchmap swap',
    (tester) async {
      final patchmapA = _buildPatchmapWithDelay(delayMs: 30);
      final patchmapB = _buildPatchmapWithDelay(delayMs: 120);
      final runtimes = <PatchmapRuntime>[];
      final readinessSnapshots = <bool>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatchmapWidget(
              patchmap: patchmapA,
              onReady: (runtime) {
                runtimes.add(runtime);
                readinessSnapshots.add(runtime.assetsReady);
              },
              builder: (context, runtime) => const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatchmapWidget(
              patchmap: patchmapB,
              onReady: (runtime) {
                runtimes.add(runtime);
                readinessSnapshots.add(runtime.assetsReady);
              },
              builder: (context, runtime) => const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await pumpUntil(tester, () => runtimes.isNotEmpty, maxPumps: 300);
      await pumpFor(tester, 80);

      expect(runtimes, hasLength(1));
      expect(runtimes.single, same(patchmapB.app));
      expect(runtimes.single.assetsReady, isTrue);
      expect(readinessSnapshots, [true]);
    },
  );
}

Patchmap _buildPatchmapWithDelay({required int delayMs}) {
  Future<String> delayedSvgLoader(String _) async {
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    return '<svg viewBox="0 0 24 24"></svg>';
  }

  final runtime = PatchmapRuntime(
    assetRegistry: PatchmapAssetRegistry(assetStringLoader: delayedSvgLoader),
  );
  return Patchmap(runtime: runtime);
}
