import '../../domain/elements/text_element.dart';
import 'element_render_host.dart';
import 'text_render_layer.dart';

bool _registered = false;

void ensureBuiltinElementRenderLayersRegistered() {
  if (_registered) {
    return;
  }

  ElementRenderHost.registerLayerFactory(
    TextElement.elementType,
    () => TextRenderLayer(),
  );
  _registered = true;
}
