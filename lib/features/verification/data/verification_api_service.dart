import 'package:dio/dio.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/network/dio_client.dart';
import 'models/atl_status_model.dart';
import 'models/cpr_status_model.dart';
import 'models/ntn_profile_model.dart';

class VerificationApiService {
  VerificationApiService({Dio? dio}) : _dio = dio ?? DioClient.create();

  final Dio _dio;

  Future<AtlStatusModel> checkAtlStatus(
    String cnic, {
    bool forceRefresh = false,
  }) async {
    _ensureBackendConfigured();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/atl/status',
        queryParameters: {'cnic': cnic, 'forceRefresh': forceRefresh},
      );
      return AtlStatusModel.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiExceptionMapper.map(error);
    }
  }

  Future<NtnProfileModel> lookupNtnProfile(String cnic) async {
    _ensureBackendConfigured();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/ntn/profile',
        queryParameters: {'cnic': cnic},
      );
      return NtnProfileModel.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiExceptionMapper.map(error);
    }
  }

  Future<CprStatusModel> submitCpr(String cprNumber) async {
    _ensureBackendConfigured();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/cpr/track',
        data: {'cprNumber': cprNumber},
      );
      return CprStatusModel.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiExceptionMapper.map(error);
    }
  }

  Future<CprStatusModel> fetchCprStatus(String cprNumber) async {
    _ensureBackendConfigured();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/cpr/status',
        queryParameters: {'cprNumber': cprNumber},
      );
      return CprStatusModel.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiExceptionMapper.map(error);
    }
  }

  void _ensureBackendConfigured() {
    if (_dio.options.baseUrl.trim().isEmpty) {
      throw const ApiException(
        'Verification backend is not configured.',
        ApiErrorCode.backendNotConfigured,
      );
    }
  }
}
