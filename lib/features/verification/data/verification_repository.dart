import 'dart:async';

import '../../../core/validation/fbr_validators.dart';
import 'models/atl_status_model.dart';
import 'models/cpr_status_model.dart';
import 'models/ntn_profile_model.dart';
import 'verification_api_service.dart';

class VerificationRepository {
  VerificationRepository({VerificationApiService? apiService})
    : _apiService = apiService ?? VerificationApiService();

  final VerificationApiService _apiService;

  Future<AtlStatusModel> checkAtlStatus(
    String cnic, {
    bool forceRefresh = false,
  }) {
    return _apiService.checkAtlStatus(
      CnicValidator.normalize(cnic),
      forceRefresh: forceRefresh,
    );
  }

  Future<NtnProfileModel> lookupNtnProfile(String cnic) {
    return _apiService.lookupNtnProfile(CnicValidator.normalize(cnic));
  }

  Future<CprStatusModel> trackCpr(String cprNumber) {
    return _apiService.submitCpr(cprNumber.trim());
  }

  Stream<CprStatusModel> watchCprStatus(String cprNumber) async* {
    final normalized = cprNumber.trim();
    yield await _apiService.fetchCprStatus(normalized);

    await for (final _ in Stream<void>.periodic(const Duration(seconds: 20))) {
      final status = await _apiService.fetchCprStatus(normalized);
      yield status;
      if (status.isCleared || status.isFailed) return;
    }
  }
}
