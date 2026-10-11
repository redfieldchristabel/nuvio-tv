/// A minimal Result type for operations that can fail with a typed error.
///
/// Repositories return `Future<Result<T>>` so callers handle failures
/// explicitly instead of catching exceptions through UI code.
sealed class Result<T> {
  const Result();

  factory Result.ok(T value) = Ok<T>;
  factory Result.err(AppError error) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  AppError? get errorOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final error) => error,
      };

  /// Unwrap or throw. Only for tests and call sites that have already
  /// checked [isOk].
  T get requireValue => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>(:final error) => throw StateError('Result is error: $error'),
      };
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;

  @override
  String toString() => 'Ok($value)';
}

class Err<T> extends Result<T> {
  const Err(this.error);
  final AppError error;

  @override
  String toString() => 'Err($error)';
}

/// Typed application error.
class AppError {
  const AppError({
    required this.kind,
    this.message,
    this.statusCode,
    this.cause,
  });

  final AppErrorKind kind;
  final String? message;
  final int? statusCode;
  final Object? cause;

  factory AppError.network([String? message, Object? cause]) =>
      AppError(kind: AppErrorKind.network, message: message, cause: cause);

  factory AppError.http(int statusCode, [String? message]) =>
      AppError(kind: AppErrorKind.http, message: message, statusCode: statusCode);

  factory AppError.parse([String? message, Object? cause]) =>
      AppError(kind: AppErrorKind.parse, message: message, cause: cause);

  factory AppError.notFound([String? message]) =>
      AppError(kind: AppErrorKind.notFound, message: message, statusCode: 404);

  factory AppError.timeout([String? message]) =>
      AppError(kind: AppErrorKind.timeout, message: message);

  factory AppError.unknown([String? message, Object? cause]) =>
      AppError(kind: AppErrorKind.unknown, message: message, cause: cause);

  /// User-presentable summary (English fallback; i18n layer maps kinds).
  String get userMessage {
    switch (kind) {
      case AppErrorKind.network:
        return 'Check your internet connection and try again.';
      case AppErrorKind.timeout:
        return 'The request took too long. Try again.';
      case AppErrorKind.http:
        return 'Service error ($statusCode). Try again later.';
      case AppErrorKind.parse:
        return 'The service returned unexpected data.';
      case AppErrorKind.notFound:
        return 'Not found.';
      case AppErrorKind.unknown:
        return 'Something went wrong.';
    }
  }

  @override
  String toString() =>
      'AppError(${kind.name}${statusCode != null ? ' $statusCode' : ''}'
      '${message != null ? ': $message' : ''})';
}

enum AppErrorKind { network, timeout, http, parse, notFound, unknown }
