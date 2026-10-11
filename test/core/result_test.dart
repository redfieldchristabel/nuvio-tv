import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart';

void main() {
  group('Result', () {
    test('ok carries value', () {
      final r = Result<int>.ok(42);
      expect(r.isOk, isTrue);
      expect(r.isErr, isFalse);
      expect(r.valueOrNull, 42);
      expect(r.errorOrNull, isNull);
      expect(r.requireValue, 42);
    });

    test('err carries error', () {
      final r = Result<int>.err(AppError.network('down'));
      expect(r.isOk, isFalse);
      expect(r.isErr, isTrue);
      expect(r.valueOrNull, isNull);
      expect(r.errorOrNull, isNotNull);
      expect(() => r.requireValue, throwsStateError);
    });

    test('pattern switch works', () {
      final Result<String> ok = Result.ok('a');
      final Result<String> err = Result.err(AppError.parse());
      expect(switch (ok) { Ok<String>(:final value) => value, _ => 'x' }, 'a');
      expect(switch (err) { Err<String>(:final error) => error.kind, _ => null },
          AppErrorKind.parse);
    });
  });

  group('AppError', () {
    test('factory constructors set kind', () {
      expect(AppError.network().kind, AppErrorKind.network);
      expect(AppError.http(404).kind, AppErrorKind.http);
      expect(AppError.http(404).statusCode, 404);
      expect(AppError.parse().kind, AppErrorKind.parse);
      expect(AppError.notFound().kind, AppErrorKind.notFound);
      expect(AppError.notFound().statusCode, 404);
      expect(AppError.timeout().kind, AppErrorKind.timeout);
      expect(AppError.unknown().kind, AppErrorKind.unknown);
    });

    test('userMessage is friendly per kind', () {
      expect(AppError.network().userMessage, contains('internet'));
      expect(AppError.timeout().userMessage, contains('too long'));
      expect(AppError.http(500).userMessage, contains('500'));
      expect(AppError.notFound().userMessage, contains('Not found'));
    });
  });
}
