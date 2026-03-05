import 'image_element.dart';
import 'text_element.dart';

bool _registered = false;

void ensureBuiltinElementDecodersRegistered() {
  if (_registered) {
    return;
  }

  TextElement.ensureDecoderRegistered();
  ImageElement.ensureDecoderRegistered();
  _registered = true;
}
