import 'package:dio/dio.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DioClient {
  const DioClient._();

  static const backendBaseUrl = String.fromEnvironment(
    'FBR_HELPER_API_BASE_URL',
    defaultValue: '',
  );

  static Dio create({String baseUrl = backendBaseUrl}) {
    final normalizedBaseUrl = baseUrl.trim();
    if (normalizedBaseUrl.isNotEmpty) {
      final uri = Uri.tryParse(normalizedBaseUrl);
      if (uri == null || !uri.hasAuthority || uri.scheme != 'https') {
        throw ArgumentError.value(
          baseUrl,
          'baseUrl',
          'FBR_HELPER_API_BASE_URL must be an absolute HTTPS URL.',
        );
      }
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: normalizedBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
        responseType: ResponseType.json,
        contentType: Headers.jsonContentType,
        headers: const {'Accept': 'application/json'},
        followRedirects: false,
        maxRedirects: 0,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );

    dio.interceptors.add(_TrustedApiInterceptor());

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }

    return dio;
  }
}

/// Adds short-lived Firebase credentials without ever logging them.
///
/// The API must validate both headers server-side. A modified client can skip
/// this interceptor, so it is not a substitute for backend authorization,
/// rate limiting, or DDoS protection.
class _TrustedApiInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken != null && idToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $idToken';
      }

      final appCheckToken = await FirebaseAppCheck.instance.getToken();
      if (appCheckToken != null && appCheckToken.isNotEmpty) {
        options.headers['X-Firebase-AppCheck'] = appCheckToken;
      }
    } catch (_) {
      // Authentication/App Check can be unavailable during startup. The server
      // remains the authority and must reject requests that require a token.
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final contentType = response.headers.value(Headers.contentTypeHeader);
    if (contentType != null &&
        !contentType.toLowerCase().contains('application/json')) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'The API returned an unexpected content type.',
        ),
      );
      return;
    }
    handler.next(response);
  }
}
