import '../../domain/elements/image_element.dart';
import '../../domain/elements/text_element.dart';
import 'element_render_host.dart';
import 'image_render_layer.dart';
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
  ElementRenderHost.registerLayerFactory(
    ImageElement.elementType,
    () => ImageRenderLayer(),
  );
  _registered = true;
}
