import 'package:dio/dio.dart';

enum ApiErrorCode {
  upstreamTimeout,
  upstreamUnavailable,
  captchaRequired,
  invalidCnicFormat,
  schemaChanged,
  notFound,
  rateLimited,
  backendNotConfigured,
  unknown,
}

class ApiException implements Exception {
  const ApiException(this.message, this.code);

  final String message;
  final ApiErrorCode code;

  @override
  String toString() => message;
}

class ApiExceptionMapper {
  const ApiExceptionMapper._();

  static ApiException map(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiException(
        'FBR verification service timed out. Try again.',
        ApiErrorCode.upstreamTimeout,
      );
    }

    final payload = error.response?.data;
    final rawCode = payload is Map<String, dynamic>
        ? payload['code']?.toString()
        : null;

    return switch (rawCode) {
      'CAPTCHA_REQUIRED' => const ApiException(
        'FBR verification is temporarily unavailable. Try again shortly.',
        ApiErrorCode.captchaRequired,
      ),
      'RATE_LIMITED' => const ApiException(
        'Too many requests. Please wait a moment.',
        ApiErrorCode.rateLimited,
      ),
      'INVALID_CNIC_FORMAT' => const ApiException(
        'Enter CNIC in format 00000-0000000-0.',
        ApiErrorCode.invalidCnicFormat,
      ),
      'NOT_FOUND' => const ApiException(
        'No record found.',
        ApiErrorCode.notFound,
      ),
      'UPSTREAM_SCHEMA_CHANGED' => const ApiException(
        'FBR verification is temporarily unavailable. Try again shortly.',
        ApiErrorCode.schemaChanged,
      ),
      'UPSTREAM_UNAVAILABLE' => const ApiException(
        'FBR verification service is unavailable. Try again.',
        ApiErrorCode.upstreamUnavailable,
      ),
      _ => const ApiException(
        'Something went wrong. Please try again.',
        ApiErrorCode.unknown,
      ),
    };
  }
}
