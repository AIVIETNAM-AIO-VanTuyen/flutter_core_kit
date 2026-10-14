import 'package:flutter_core_kit/repositories/interfaces/response_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('asInt: int, double, chuỗi số, bool; còn lại null', () {
    expect(asInt(7), 7);
    expect(asInt(7.9), 7);
    expect(asInt(' 12 '), 12);
    expect(asInt(true), 1);
    expect(asInt(false), 0);
    expect(asInt('abc'), isNull);
    expect(asInt(null), isNull);
    expect(asInt([1]), isNull);
  });

  test('asString: chuỗi, số, bool; map / list thành null', () {
    expect(asString('Lan'), 'Lan');
    expect(asString(12), '12');
    expect(asString(true), 'true');
    expect(asString({'a': 1}), isNull);
    expect(asString(null), isNull);
  });
}
