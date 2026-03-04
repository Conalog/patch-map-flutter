import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';
import 'package:patch_map_flutter_example/main.dart';

void main() {
  testWidgets('renders example shell', (WidgetTester tester) async {
    await tester.pumpWidget(const PatchmapExampleApp());

    expect(find.text('Patchmap Runtime Example'), findsOneWidget);
  });

  testWidgets('loads downloaded svg asset via init options', (
    WidgetTester tester,
  ) async {
    final patchmap = Patchmap();

    await patchmap.init(
      options: const PatchmapInitOptions(
        assets: PatchmapInitAssets(
          iconAssetPathByAlias: <String, String>{
            'downloaded-bolt': 'assets/icons/downloaded-bolt.svg',
          },
        ),
      ),
    );

    expect(patchmap.app.iconSvgByAlias.keys, contains('downloaded-bolt'));
    expect(patchmap.app.iconSvgByAlias['downloaded-bolt'], contains('<svg'));
  });
}
