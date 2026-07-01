const String currentTaxYear = '2026-27';
const int earliestSupportedTaxYear = 2017;
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
];

enum TaxProfileType { salaried, registeredFreelancer, unregisteredExporter }

class TaxProfile {
  final TaxProfileType type;
  final double monthlyGrossIncome;
  final String taxYear;

  const TaxProfile({
    required this.type,
    required this.monthlyGrossIncome,
    this.taxYear = currentTaxYear,
  });
}
