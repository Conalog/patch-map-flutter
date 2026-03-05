import 'package:flutter_test/flutter_test.dart';

Future<void> pumpUntil(
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

Future<void> pumpFor(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    });
    await tester.pump(const Duration(milliseconds: 16));
  }
}
