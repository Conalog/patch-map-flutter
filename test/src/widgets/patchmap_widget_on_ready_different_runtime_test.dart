import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';

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

    await _pumpUntil(tester, () => onReadyCallCount >= 1);

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

    await _pumpUntil(tester, () => onReadyCallCount >= 2);
    expect(onReadyCallCount, 2);
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    });
    await tester.pump(const Duration(milliseconds: 16));

    final exception = tester.takeException();
    if (exception != null) {
      fail('Unexpected exception while pumping: $exception');
    }

    if (condition()) {
      return;
    }
  }

  fail('Timed out waiting for condition.');
}
