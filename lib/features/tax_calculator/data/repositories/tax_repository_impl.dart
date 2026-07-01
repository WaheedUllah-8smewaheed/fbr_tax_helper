import '../../domain/entities/tax_profile.dart';
import '../datasources/tax_local_data_source.dart';
import '../models/tax_profile_model.dart';

class TaxRepositoryImpl {
  final TaxLocalDataSource localDataSource;

  const TaxRepositoryImpl({required this.localDataSource});

  Future<void> saveProfile(TaxProfile profile) async {
    final model = TaxProfileModel(
      type: profile.type,
      monthlyGrossIncome: profile.monthlyGrossIncome,
      taxYear: profile.taxYear,
    );
    await localDataSource.cacheTaxProfile(model);
  }

  Future<TaxProfile?> loadProfile() async {
    return await localDataSource.getLastTaxProfile();
  }

  Future<void> clearProfile() async {
    await localDataSource.clearTaxProfile();
  }
}
