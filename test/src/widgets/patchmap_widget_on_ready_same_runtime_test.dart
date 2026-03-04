import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';

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

    await _pumpUntil(tester, () => onReadyCallCount >= 1);

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

    expect(find.byType(CircularProgressIndicator), findsNothing);
    await _pumpFor(tester, 40);
    expect(onReadyCallCount, 1);
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

Future<void> _pumpFor(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    });
    await tester.pump(const Duration(milliseconds: 16));
  }
}
