const String currentTaxYear = '2023-24';
const List<String> supportedTaxYears = ['2023-24', '2022-23'];

enum TaxProfileType {
  salaried,
  registeredFreelancer,
  unregisteredExporter,
}

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
          taxYear == other.taxYear;

  @override
  int get hashCode =>
      type.hashCode ^ monthlyGrossIncome.hashCode ^ taxYear.hashCode;
}
