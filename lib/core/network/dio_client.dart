import 'package:dio/dio.dart';

class DioClient {
  const DioClient._();

  static const backendBaseUrl = String.fromEnvironment(
    'FBR_HELPER_API_BASE_URL',
    defaultValue: '',
  );

  static Dio create({String baseUrl = backendBaseUrl}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
        responseType: ResponseType.json,
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
      ),
    );

    return dio;
  }
}
