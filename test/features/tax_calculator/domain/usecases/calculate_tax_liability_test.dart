import 'package:fbr_tax_helper/features/tax_calculator/domain/entities/tax_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fbr_tax_helper/features/tax_calculator/domain/usecases/calculate_tax_liability.dart';

void main() {
  late CalculateTaxLiability usecase;

  setUp(() {
    usecase = const CalculateTaxLiability();
  });

  test('should expose fiscal years from 2015-16 through 2026-27', () {
    expect(supportedTaxYears.length, 12);
    expect(supportedTaxYears.first, '2026-27');
    expect(supportedTaxYears.last, '2015-16');
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
      taxYear: '2024-25',
    );

    final result = usecase.execute(profile);

    expect(result.annualTaxLiability, 120000.0);
    expect(result.monthlyTaxLiability, 10000.0);
  });

  test('should match the historical calculator for every supported year', () {
    const expectedAnnualTaxAt150kMonthly = <String, double>{
      '2026-27': 72000,
      '2025-26': 72000,
      '2024-25': 120000,
      '2023-24': 90000,
      '2022-23': 90000,
      '2021-22': 90000,
      '2020-21': 90000,
      '2019-20': 90000,
      '2018-19': 30000,
      '2017-18': 137000,
      '2016-17': 137000,
      '2015-16': 137000,
    };

    for (final entry in expectedAnnualTaxAt150kMonthly.entries) {
      final result = usecase.execute(
        TaxProfile(
          type: TaxProfileType.salaried,
          monthlyGrossIncome: 150000,
          taxYear: entry.key,
        ),
      );

      expect(
        result.annualTaxLiability,
        entry.value,
        reason: 'Incorrect calculation for ${entry.key}',
      );
    }
  });

  test('should apply the high-income surcharge only from 2025-26', () {
    const monthlyIncome = 1000000.0;

    final tax2024 = usecase.execute(
      const TaxProfile(
        type: TaxProfileType.salaried,
        monthlyGrossIncome: monthlyIncome,
        taxYear: '2024-25',
      ),
    );
    final tax2025 = usecase.execute(
      const TaxProfile(
        type: TaxProfileType.salaried,
        monthlyGrossIncome: monthlyIncome,
        taxYear: '2025-26',
      ),
    );

    expect(tax2024.annualTaxLiability, 3465000);
    expect(tax2025.annualTaxLiability, 3685290);
  });

  test('should calculate the 2018-19 minimum-tax band correctly', () {
    final result = usecase.execute(
      const TaxProfile(
        type: TaxProfileType.salaried,
        monthlyGrossIncome: 101000,
        taxYear: '2018-19',
      ),
    );

    expect(result.annualTaxLiability, 2000);
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
    expect(result.annualTaxBeforeAdjustments, 72000.0);
    expect(result.annualAdjustableTaxPaid, 12000.0);
    expect(result.annualTaxLiability, 72000.0 - 12000.0);
  });
}
