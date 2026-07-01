// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
// 1. Explicitly import the data sources and models to resolve type definitions
import 'package:fbr_tax_helper/features/tax_calculator/data/datasources/tax_local_data_source.dart';
import 'package:fbr_tax_helper/features/tax_calculator/data/models/tax_profile_model.dart';
import 'package:fbr_tax_helper/features/tax_calculator/data/repositories/tax_repository_impl.dart';
import 'package:fbr_tax_helper/features/tax_calculator/domain/entities/tax_profile.dart';
import 'package:fbr_tax_helper/features/tax_calculator/domain/usecases/calculate_tax_liability.dart';
import 'package:fbr_tax_helper/features/tax_calculator/presentation/bloc/tax_calculator_bloc.dart';
import 'package:fbr_tax_helper/features/tax_calculator/presentation/bloc/tax_calculator_state.dart';

// 2. Correctly implement the abstract data source with exact type matches
class FakeLocalDataSourceImpl implements TaxLocalDataSource {
  @override
  Future<void> cacheTaxProfile(TaxProfileModel profileToCache) async {}

  @override
  Future<TaxProfileModel?> getLastTaxProfile() async => null;

  @override
  Future<void> clearTaxProfile() async {}
}

// 3. Subclass the implementation repository cleanly
class FakeTaxRepositoryImpl extends TaxRepositoryImpl {
  FakeTaxRepositoryImpl() : super(localDataSource: FakeLocalDataSourceImpl());

  @override
  Future<void> saveProfile(TaxProfile profile) async {}

  @override
  Future<TaxProfile?> loadProfile() async => null;

  @override
  Future<void> clearProfile() async {}
}

void main() {
  late TaxCalculatorBloc bloc;

  setUp(() {
    bloc = TaxCalculatorBloc(
      calculateTaxUseCase: const CalculateTaxLiability(),
      repository: FakeTaxRepositoryImpl(),
    );
  });

  test('initial state should be TaxCalculatorInitial', () {
    expect(bloc.state, isA<TaxCalculatorInitial>());
  });
}
