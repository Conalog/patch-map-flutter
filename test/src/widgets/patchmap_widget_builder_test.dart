import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('uses custom ready builder when provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatchmapWidget(
            builder: (context, runtime) {
              return Text('ready: ${runtime.assetsReady}');
            },
          ),
        ),
      ),
    );

    await _pumpUntil(
      tester,
      () => find.text('ready: true').evaluate().isNotEmpty,
    );

    expect(find.text('ready: true'), findsOneWidget);
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
