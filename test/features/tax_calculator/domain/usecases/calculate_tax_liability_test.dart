import 'package:fbr_tax_helper/features/tax_calculator/domain/entities/tax_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fbr_tax_helper/features/tax_calculator/domain/usecases/calculate_tax_liability.dart';

void main() {
  late CalculateTaxLiability usecase;

  setUp(() {
    usecase = const CalculateTaxLiability();
  });

  test('should return zero tax when annual salary is below 600k PKR', () {
    const profile = TaxProfile(
      type: TaxProfileType.salaried,
      monthlyGrossIncome: 45000,
    );

    final result = usecase.execute(profile);

    expect(result.annualTaxLiability, 0.0);
    expect(result.monthlyTaxLiability, 0.0);
  });

  test(
    'should accurately evaluate current-year progressive tax on middle income brackets',
    () {
      const profile = TaxProfile(
        type: TaxProfileType.salaried,
        monthlyGrossIncome: 150000,
      );

      final result = usecase.execute(profile);

      expect(result.annualTaxLiability, 72000.0);
      expect(result.monthlyTaxLiability, 6000.0);
    },
  );

  test('should use the selected previous tax year slabs', () {
    const profile = TaxProfile(
      type: TaxProfileType.salaried,
      monthlyGrossIncome: 150000,
      taxYear: '2025',
    );

    final result = usecase.execute(profile);

    expect(result.annualTaxLiability, 120000.0);
    expect(result.monthlyTaxLiability, 10000.0);
  });

  test('should subtract deductions from the final tax liability', () {
    // Given a user with income and advance tax payments
    const profile = TaxProfile(
      type: TaxProfileType.salaried,
      monthlyGrossIncome: 150000, // Annual income: 1,800,000
      advanceTaxOnMobile: 5000,
      taxOnElectricityBill: 2000,
      taxOnInternetBill: 1000,
      vehicleTokenTax: 4000,
    );

    // When the tax liability is calculated
    final result = usecase.execute(profile);

    // Then the deductions should be subtracted from the gross tax liability
    // Gross Annual Tax on 1.8M is 72,000
    // Total Deductions = 5000 + 2000 + 1000 + 4000 = 12000
    expect(result.annualTaxLiability, 72000.0 - 12000.0);
  });
}
