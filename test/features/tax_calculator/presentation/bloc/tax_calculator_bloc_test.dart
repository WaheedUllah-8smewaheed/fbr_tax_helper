import 'package:flutter_test/flutter_test.dart';
import 'package:fbr_tax_helper/features/tax_calculator/data/datasources/tax_local_data_source.dart';
import 'package:fbr_tax_helper/features/tax_calculator/data/models/tax_profile_model.dart';
import 'package:fbr_tax_helper/features/tax_calculator/data/repositories/tax_repository_impl.dart';
import 'package:fbr_tax_helper/features/tax_calculator/domain/usecases/calculate_tax_liability.dart';
import 'package:fbr_tax_helper/features/tax_calculator/presentation/bloc/tax_calculator_bloc.dart';
import 'package:fbr_tax_helper/features/tax_calculator/presentation/bloc/tax_calculator_state.dart';

class FakeLocalDataSource implements TaxLocalDataSource {
  TaxProfileModel? cachedProfile;

  @override
  Future<void> cacheTaxProfile(TaxProfileModel profileToCache) async {
    cachedProfile = profileToCache;
  }

  @override
  Future<TaxProfileModel?> getLastTaxProfile() async => cachedProfile;

  @override
  Future<void> clearTaxProfile() async {
    cachedProfile = null;
  }
}

void main() {
  late TaxCalculatorBloc bloc;

  setUp(() {
    final localDataSource = FakeLocalDataSource();
    bloc = TaxCalculatorBloc(
      calculateTaxUseCase: const CalculateTaxLiability(),
      repository: TaxRepositoryImpl(localDataSource: localDataSource),
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  test('initial state should be TaxCalculatorInitial', () {
    expect(bloc.state, isA<TaxCalculatorInitial>());
  });
}
