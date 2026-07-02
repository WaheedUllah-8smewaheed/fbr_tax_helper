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
  final double advanceTaxOnMobile;
  final double taxOnElectricityBill;
  final double taxOnInternetBill;
  final double vehicleTokenTax;

  const CalculateTaxEvent({
    required this.profileType,
    required this.monthlySalary,
    this.taxYear = currentTaxYear,
    this.advanceTaxOnMobile = 0.0,
    this.taxOnElectricityBill = 0.0,
    this.taxOnInternetBill = 0.0,
    this.vehicleTokenTax = 0.0,
  });
}
