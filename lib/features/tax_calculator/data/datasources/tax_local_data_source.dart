import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/tax_profile_model.dart';

abstract class TaxLocalDataSource {
  Future cacheTaxProfile(TaxProfileModel profileToCache);
  Future<TaxProfileModel?> getLastTaxProfile();
  Future<void> clearTaxProfile();
}

class TaxLocalDataSourceImpl implements TaxLocalDataSource {
  final FlutterSecureStorage secureStorage;
  static const String _profileKey = 'CACHED_TAX_PROFILE';

  const TaxLocalDataSourceImpl({required this.secureStorage});

  @override
  Future cacheTaxProfile(TaxProfileModel profileToCache) async {
    final String secureJsonString = jsonEncode(profileToCache.toMap());
    await secureStorage.write(key: _profileKey, value: secureJsonString);
  }

  @override
  Future<TaxProfileModel?> getLastTaxProfile() async {
    final String? secureJsonString = await secureStorage.read(key: _profileKey);
    if (secureJsonString != null) {
      final Map<String, dynamic> decodedMap =
          jsonDecode(secureJsonString) as Map<String, dynamic>;
      return TaxProfileModel.fromMap(decodedMap);
    }
    return null;
  }

  @override
  Future<void> clearTaxProfile() async {
    await secureStorage.delete(key: _profileKey);
  }
}
