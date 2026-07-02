const String currentTaxYear = '2026-27';
const List<String> supportedTaxYears = [
  '2026-27',
  '2025-26',
  '2024-25',
  '2023-24',
  '2022-23',
  '2021-22',
  '2020-21',
  '2019-20',
  '2018-19',
  '2017-18',
  '2016-17',
  '2015-16',
];

enum TaxProfileType { salaried, registeredFreelancer, unregisteredExporter }

class TaxProfile {
  final TaxProfileType type;
  final double monthlyGrossIncome;
  final String taxYear;
  final double advanceTaxOnMobile;
  final double taxOnElectricityBill;
  final double taxOnInternetBill;
  final double vehicleTokenTax;

  const TaxProfile({
    required this.type,
    required this.monthlyGrossIncome,
    this.taxYear = currentTaxYear,
    this.advanceTaxOnMobile = 0.0,
    this.taxOnElectricityBill = 0.0,
    this.taxOnInternetBill = 0.0,
    this.vehicleTokenTax = 0.0,
  });

  double get totalAnnualDeductions =>
      advanceTaxOnMobile +
      taxOnElectricityBill +
      taxOnInternetBill +
      vehicleTokenTax;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxProfile &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          monthlyGrossIncome == other.monthlyGrossIncome &&
          taxYear == other.taxYear &&
          advanceTaxOnMobile == other.advanceTaxOnMobile &&
          taxOnElectricityBill == other.taxOnElectricityBill &&
          taxOnInternetBill == other.taxOnInternetBill &&
          vehicleTokenTax == other.vehicleTokenTax;

  @override
  int get hashCode =>
      type.hashCode ^
      monthlyGrossIncome.hashCode ^
      taxYear.hashCode ^
      advanceTaxOnMobile.hashCode ^
      taxOnElectricityBill.hashCode ^
      taxOnInternetBill.hashCode ^
      vehicleTokenTax.hashCode;
}
