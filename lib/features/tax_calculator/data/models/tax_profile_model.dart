import '../../domain/entities/tax_profile.dart';

class TaxProfileModel extends TaxProfile {
  const TaxProfileModel({
    required super.type,
    required super.monthlyGrossIncome,
    super.taxYear,
    super.advanceTaxOnMobile,
    super.taxOnElectricityBill,
    super.taxOnInternetBill,
    super.vehicleTokenTax,
  });

  /// Factory constructor to map structured string records into our app domain values
  factory TaxProfileModel.fromMap(Map<String, dynamic> map) {
    final rawTaxYear = map['taxYear'];
    final parsedTaxYear = rawTaxYear == null
        ? currentTaxYear
        : rawTaxYear.toString().trim();

    return TaxProfileModel(
      type: TaxProfileType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TaxProfileType.salaried,
      ),
      monthlyGrossIncome: (map['monthlyGrossIncome'] as num).toDouble(),
      taxYear: parsedTaxYear.isEmpty ? currentTaxYear : parsedTaxYear,
      advanceTaxOnMobile: _readDouble(map['advanceTaxOnMobile']),
      taxOnElectricityBill: _readDouble(map['taxOnElectricityBill']),
      taxOnInternetBill: _readDouble(map['taxOnInternetBill']),
      vehicleTokenTax: _readDouble(map['vehicleTokenTax']),
    );
  }

  /// Converts our profile entity records into flat data maps for encrypted persistence storage
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'monthlyGrossIncome': monthlyGrossIncome,
      'taxYear': taxYear,
      'advanceTaxOnMobile': advanceTaxOnMobile,
      'taxOnElectricityBill': taxOnElectricityBill,
      'taxOnInternetBill': taxOnInternetBill,
      'vehicleTokenTax': vehicleTokenTax,
    };
  }

  static double _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
