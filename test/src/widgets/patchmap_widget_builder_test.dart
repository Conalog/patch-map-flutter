import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';

import '../helpers/widget_pump.dart';

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

    await pumpUntil(
      tester,
      () => find.text('ready: true').evaluate().isNotEmpty,
    );

    expect(find.text('ready: true'), findsOneWidget);
  });
}
