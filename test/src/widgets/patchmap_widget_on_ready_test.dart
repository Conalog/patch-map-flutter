import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';

import '../helpers/widget_pump.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('calls onReady once when initialization completes', (
    tester,
  ) async {
    var onReadyCallCount = 0;
    PatchmapRuntime? runtime;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatchmapWidget(
            onReady: (value) {
              onReadyCallCount += 1;
              runtime = value;
            },
            builder: (context, runtime) => const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await pumpUntil(tester, () => onReadyCallCount == 1);

    expect(onReadyCallCount, 1);
    expect(runtime, isA<PatchmapRuntime>());
  });
}
