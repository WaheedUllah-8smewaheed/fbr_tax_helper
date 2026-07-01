import '../../domain/entities/tax_profile.dart';

abstract class TaxCalculatorEvent {
  const TaxCalculatorEvent();
}

class LoadSavedProfileEvent extends TaxCalculatorEvent {
  const LoadSavedProfileEvent();
}

class ResetCalculatorEvent extends TaxCalculatorEvent {
  const ResetCalculatorEvent();
}

class CalculateTaxEvent extends TaxCalculatorEvent {
  final TaxProfileType profileType;
  final double monthlySalary;
  final String taxYear;

  const CalculateTaxEvent({
    required this.profileType,
    required this.monthlySalary,
    this.taxYear = currentTaxYear,
  });
}
