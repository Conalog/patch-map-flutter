import 'text_element.dart';

bool _registered = false;

void ensureBuiltinElementDecodersRegistered() {
  if (_registered) {
    return;
  }

  TextElement.ensureDecoderRegistered();
  _registered = true;
}
