import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';

import '../helpers/widget_pump.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('uses custom error builder when initialization fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatchmapWidget(
            options: const PatchmapInitOptions(
              assets: PatchmapInitAssets(
                iconAssetPathByAlias: <String, String>{
                  'broken': 'assets/icons/does-not-exist.svg',
                },
              ),
            ),
            errorBuilder: (context, error, stackTrace) {
              return Text('error: ${error.runtimeType}');
            },
          ),
        ),
      ),
    );

    await pumpUntil(
      tester,
      () => find.textContaining('error:').evaluate().isNotEmpty,
    );

    expect(find.textContaining('error:'), findsOneWidget);
  });
}
