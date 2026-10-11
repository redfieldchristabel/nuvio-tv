import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../util/result.dart';

/// Thin HTTP client wrapper used by every remote API.
///
/// Adds: timeouts, single retry on transient failures, JSON decoding,
/// and consistent error mapping to [AppError].
class HttpClient {
  HttpClient({
    http.Client? client,
    this.connectTimeout = const Duration(seconds: 10),
    this.requestTimeout = const Duration(seconds: 20),
    this.maxRetries = 1,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration connectTimeout;
  final Duration requestTimeout;
  final int maxRetries;

  /// GET a JSON resource. Returns parsed body or [AppError].
  Future<Result<dynamic>> getJson(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return _run(
      () => _client.get(url, headers: headers),
      timeout: timeout,
      decoder: (body) => body.isEmpty ? null : jsonDecode(body),
    );
  }

  /// GET raw bytes (images, subtitle files).
  Future<Result<List<int>>> getBytes(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return _run(
      () => _client.get(url, headers: headers),
      timeout: timeout,
      decoder: null,
      rawBytes: true,
    );
  }

  /// POST a JSON body, expect JSON response.
  Future<Result<dynamic>> postJson(
    Uri url, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return _run(
      () => _client.post(
            url,
            headers: {
              'content-type': 'application/json',
              ...?headers,
            },
            body: body == null ? null : jsonEncode(body),
          ),
      timeout: timeout,
      decoder: (raw) => raw.isEmpty ? null : jsonDecode(raw),
    );
  }

  Future<Result<T>> _run<T>(
    Future<http.Response> Function() request, {
    required Duration? timeout,
    required T? Function(String body)? decoder,
    bool rawBytes = false,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await request().timeout(
          timeout ?? requestTimeout,
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (rawBytes) {
            return Result.ok(response.bodyBytes as T);
          }
          final decoded = decoder?.call(response.body);
          return Result.ok(decoded as T);
        }
        // 4xx: don't retry (client error).
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return Result.err(AppError.http(
            response.statusCode,
            _safeBodyMessage(response.body),
          ));
        }
        // 5xx: retryable.
        if (attempt <= maxRetries) continue;
        return Result.err(AppError.http(response.statusCode));
      } on TimeoutException {
        if (attempt <= maxRetries) continue;
        return Result.err(AppError.timeout('Request timed out'));
      } on http.ClientException catch (e) {
        if (attempt <= maxRetries) continue;
        return Result.err(AppError.network('Network error', e));
      } on FormatException catch (e) {
        return Result.err(AppError.parse('Invalid JSON', e));
      } catch (e) {
        if (attempt <= maxRetries) continue;
        return Result.err(AppError.unknown('Unexpected error', e));
      }
    }
  }

  String? _safeBodyMessage(String body) {
    if (body.length > 200) return null;
    return body.isEmpty ? null : body;
  }

  void close() => _client.close();
}
