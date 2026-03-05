import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';

import '../helpers/widget_pump.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('calls onReady once for each different runtime', (tester) async {
    final patchmapA = Patchmap();
    final patchmapB = Patchmap();
    var onReadyCallCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatchmapWidget(
            patchmap: patchmapA,
            onReady: (_) {
              onReadyCallCount += 1;
            },
            builder: (context, runtime) => const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await pumpUntil(tester, () => onReadyCallCount >= 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatchmapWidget(
            patchmap: patchmapB,
            onReady: (_) {
              onReadyCallCount += 1;
            },
            builder: (context, runtime) => const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await pumpUntil(tester, () => onReadyCallCount >= 2);
    expect(onReadyCallCount, 2);
  });
}
