import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';

import '../helpers/widget_pump.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('does not call onReady again for the same runtime', (
    tester,
  ) async {
    final patchmap = Patchmap();
    var onReadyCallCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatchmapWidget(
            patchmap: patchmap,
            options: const PatchmapInitOptions(
              app: PatchmapInitAppOptions(backgroundColor: Color(0xFFFFFFFF)),
            ),
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
            patchmap: patchmap,
            options: const PatchmapInitOptions(
              app: PatchmapInitAppOptions(backgroundColor: Color(0xFF000000)),
            ),
            onReady: (_) {
              onReadyCallCount += 1;
            },
            builder: (context, runtime) => const SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(patchmap.app.backgroundColor(), const Color(0xFFFFFFFF));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await pumpFor(tester, 40);
    expect(onReadyCallCount, 1);
    expect(patchmap.app.backgroundColor(), const Color(0xFFFFFFFF));
  });
}
