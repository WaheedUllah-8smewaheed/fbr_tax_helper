import '../../domain/entities/tax_assessment.dart';
import '../../domain/entities/tax_profile.dart';

abstract class TaxCalculatorState {
  const TaxCalculatorState();
}

class TaxCalculatorInitial extends TaxCalculatorState {}

class TaxCalculatorLoading extends TaxCalculatorState {}

class TaxCalculatorCalculated extends TaxCalculatorState {
  final TaxAssessment assessment;
  final TaxProfileType selectedType;
  final double inputSalary;
  final String taxYear;
  final double advanceTaxOnMobile;
  final double taxOnElectricityBill;
  final double taxOnInternetBill;
  final double vehicleTokenTax;

  const TaxCalculatorCalculated({
    required this.assessment,
    required this.selectedType,
    required this.inputSalary,
    this.taxYear = currentTaxYear,
    this.advanceTaxOnMobile = 0.0,
    this.taxOnElectricityBill = 0.0,
    this.taxOnInternetBill = 0.0,
    this.vehicleTokenTax = 0.0,
  });
}

class TaxCalculatorError extends TaxCalculatorState {
  final String errorMessage;
  const TaxCalculatorError({required this.errorMessage});
}
