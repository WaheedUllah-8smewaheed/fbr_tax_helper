import 'package:bloc/bloc.dart';
import '../../data/repositories/tax_repository_impl.dart';
import '../../domain/entities/tax_profile.dart';
import '../../domain/usecases/calculate_tax_liability.dart';
import 'tax_calculator_event.dart';
import 'tax_calculator_state.dart';

class TaxCalculatorBloc extends Bloc<TaxCalculatorEvent, TaxCalculatorState> {
  final CalculateTaxLiability calculateTaxUseCase;
  final TaxRepositoryImpl repository;

  TaxCalculatorBloc({
    required this.calculateTaxUseCase,
    required this.repository,
  }) : super(TaxCalculatorInitial()) {
    on<LoadSavedProfileEvent>(_onLoadSavedProfile);
    on<ResetCalculatorEvent>(_onResetCalculator);
    on<CalculateTaxEvent>(_onCalculateTax);
  }

  Future<void> _onLoadSavedProfile(
    LoadSavedProfileEvent event,
    Emitter<TaxCalculatorState> emit,
  ) async {
    emit(TaxCalculatorLoading());
    try {
      final savedProfile = await repository.loadProfile();
      if (savedProfile != null) {
        final assessment = calculateTaxUseCase.execute(savedProfile);
        emit(
          TaxCalculatorCalculated(
            assessment: assessment,
            selectedType: savedProfile.type,
            inputSalary: savedProfile.monthlyGrossIncome,
            taxYear: savedProfile.taxYear, // This is now a string
          ),
        );
      } else {
        emit(TaxCalculatorInitial());
      }
    } catch (_) {
      emit(TaxCalculatorInitial());
    }
  }

  Future<void> _onCalculateTax(
    CalculateTaxEvent event,
    Emitter<TaxCalculatorState> emit,
  ) async {
    emit(TaxCalculatorLoading());
    try {
      final profile = TaxProfile(
        type: event.profileType,
        monthlyGrossIncome: event.monthlySalary,
        taxYear: event.taxYear,
      );

      // Execute Domain rule logic calculations
      final assessment = calculateTaxUseCase.execute(profile);

      // Local persistence is helpful, but tax calculation should still work if
      // Android secure storage is unavailable or migrating keys.
      try {
        await repository.saveProfile(profile);
      } catch (_) {}

      emit(
        TaxCalculatorCalculated(
          assessment: assessment,
          selectedType: event.profileType,
          inputSalary: event.monthlySalary,
          taxYear: event.taxYear,
        ),
      );
    } catch (_) {
      emit(
        const TaxCalculatorError(
          errorMessage: 'Calculation operation interrupted.',
        ),
      );
    }
  }

  Future<void> _onResetCalculator(
    ResetCalculatorEvent event,
    Emitter<TaxCalculatorState> emit,
  ) async {
    try {
      await repository.clearProfile();
    } catch (_) {}

    emit(TaxCalculatorInitial());
  }
}
