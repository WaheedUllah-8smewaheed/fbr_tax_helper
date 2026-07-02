class TaxAssessment {
  final double annualGrossIncome;
  final double annualTaxBeforeAdjustments;
  final double annualAdjustableTaxPaid;
  final double annualTaxLiability;
  final double monthlyTaxLiability;
  final double monthlyTakeHomePay;
  final double effectiveTaxRate;

  const TaxAssessment({
    required this.annualGrossIncome,
    required this.annualTaxBeforeAdjustments,
    required this.annualAdjustableTaxPaid,
    required this.annualTaxLiability,
    required this.monthlyTaxLiability,
    required this.monthlyTakeHomePay,
    required this.effectiveTaxRate,
  });
}
