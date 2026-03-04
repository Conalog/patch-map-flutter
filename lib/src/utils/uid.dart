import 'package:nanoid2/nanoid2.dart';

// patch-map/src/utils/uuid.js parity:
// - base62 alphabet
// - fixed length 15
const _alphabet =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

String uid() => nanoid(alphabet: _alphabet, length: 15);
