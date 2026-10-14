import 'package:flutter_core_kit/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('map giữ nguyên lỗi, chỉ biến đổi giá trị', () {
    expect(const Result<int>.ok(2).map((int v) => v * 10), const Ok<int>(20));
    const Err<int> err = Err<int>(NetworkFailure());
    expect(err.map((int v) => v * 10).failureOrNull, same(err.failure));
  });

  test('JSON sai hình dạng trong map → ParseFailure thay vì ném', () {
    final Result<String> result = const Result<Object?>.ok({
      'id': 1,
    }).map((Object? json) => (json! as Map)['name'] as String);
    expect(result.failureOrNull, isA<ParseFailure>());

    final Result<int> format = const Result<String>.ok('abc').map(int.parse);
    expect(format.failureOrNull, isA<ParseFailure>());
  });

  test('lỗi code (không phải dữ liệu) vẫn nổi lên', () {
    expect(() => const Result<int>.ok(1).map<int>((_) => throw StateError('bug')), throwsStateError);
  });

  test('fold / getOrElse / flatMap', () {
    expect(const Result<int>.ok(1).fold(ok: (int v) => 'ok $v', err: (_) => 'err'), 'ok 1');
    expect(const Result<int>.err(ServerFailure()).getOrElse((_) => -1), -1);
    expect(
      const Result<int>.ok(1).flatMap((int v) => const Result<String>.err(ApiFailure(message: 'x'))).failureOrNull,
      isA<ApiFailure>(),
    );
  });
}
