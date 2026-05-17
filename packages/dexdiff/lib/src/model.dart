// cspell:words uleb sleb mutf Ljava
import 'package:meta/meta.dart';

part 'model/identifiers.dart';
part 'model/encoded_value.dart';
part 'model/annotation.dart';
part 'model/class_definition.dart';
part 'model/executable_header.dart';
part 'model/dalvik_executable.dart';

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
