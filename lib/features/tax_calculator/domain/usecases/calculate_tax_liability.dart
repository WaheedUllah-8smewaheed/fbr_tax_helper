import '../entities/tax_assessment.dart';
import '../entities/tax_profile.dart';

class CalculateTaxLiability {
  const CalculateTaxLiability();

  TaxAssessment execute(TaxProfile profile) {
    final double annualGross = profile.monthlyGrossIncome * 12;
    double annualTax = 0.0;

    switch (profile.type) {
      case TaxProfileType.registeredFreelancer:
        // Concessionary tax status for PSEB registered entities: 0.25% flat rate
        annualTax = annualGross * 0.0025;
        break;
      case TaxProfileType.unregisteredExporter:
        // Unregistered IT exporters fixed withholding tier rate: 1.0% flat rate
        annualTax = annualGross * 0.01;
        break;
      case TaxProfileType.salaried:
        annualTax = _computeSalariedProgressiveTax(
          annualGross,
          profile.taxYear,
        );
        break;
    }

    // Apply surcharge for high income earners
    if (annualGross > 10000000) {
      annualTax *= 1.09;
    }

    final double monthlyTax = annualTax / 12;
    final double monthlyTakeHome = profile.monthlyGrossIncome - monthlyTax;
    final double effectiveRate = annualGross > 0
        ? (annualTax / annualGross) * 100
        : 0.0;

    return TaxAssessment(
      annualGrossIncome: annualGross,
      annualTaxLiability: annualTax,
      monthlyTaxLiability: monthlyTax,
      monthlyTakeHomePay: monthlyTakeHome,
      effectiveTaxRate: effectiveRate,
    );
  }

  double _computeSalariedProgressiveTax(double annualGross, String taxYearString) {
    // Fiscal year '2025-26' corresponds to tax year 2026.
    final year = int.tryParse(taxYearString.split('-').first) ?? 0;
    final taxYear = year + 1;

    final slabs =
        _salariedSlabsByTaxYear[taxYear] ?? _salariedSlabsByTaxYear[2027]!;
    final slab = slabs.firstWhere((item) => annualGross <= item.upperLimit);
    return slab.fixedTax + ((annualGross - slab.excessOver) * slab.rate);
  }
}

class _TaxSlab {
  final double upperLimit;
  final double fixedTax;
  final double excessOver;
  final double rate;

  const _TaxSlab({
    required this.upperLimit,
    required this.fixedTax,
    required this.excessOver,
    required this.rate,
  });
}

const _infinity = double.infinity;

const _salariedSlabs2027 = [
  _TaxSlab(upperLimit: 600000, fixedTax: 0, excessOver: 0, rate: 0),
  _TaxSlab(upperLimit: 1200000, fixedTax: 0, excessOver: 600000, rate: 0.01),
  _TaxSlab(
    upperLimit: 2200000,
    fixedTax: 6000,
    excessOver: 1200000,
    rate: 0.11,
  ),
  _TaxSlab(
    upperLimit: 3200000,
    fixedTax: 116000,
    excessOver: 2200000,
    rate: 0.20,
  ),
  _TaxSlab(
    upperLimit: 4100000,
    fixedTax: 316000,
    excessOver: 3200000,
    rate: 0.25,
  ),
  _TaxSlab(
    upperLimit: 5600000,
    fixedTax: 541000,
    excessOver: 4100000,
    rate: 0.29,
  ),
  _TaxSlab(
    upperLimit: 7000000,
    fixedTax: 976000,
    excessOver: 5600000,
    rate: 0.32,
  ),
  _TaxSlab(
    upperLimit: _infinity,
    fixedTax: 1424000,
    excessOver: 7000000,
    rate: 0.35,
  ),
];

const _salariedSlabs2026 = [
  _TaxSlab(upperLimit: 600000, fixedTax: 0, excessOver: 0, rate: 0),
  _TaxSlab(upperLimit: 1200000, fixedTax: 0, excessOver: 600000, rate: 0.05),
  _TaxSlab(
    upperLimit: 2200000,
    fixedTax: 30000,
    excessOver: 1200000,
    rate: 0.15,
  ),
  _TaxSlab(
    upperLimit: 3200000,
    fixedTax: 180000,
    excessOver: 2200000,
    rate: 0.25,
  ),
  _TaxSlab(
    upperLimit: 4100000,
    fixedTax: 430000,
    excessOver: 3200000,
    rate: 0.30,
  ),
  _TaxSlab(
    upperLimit: _infinity,
    fixedTax: 700000,
    excessOver: 4100000,
    rate: 0.35,
  ),
];

const _salariedSlabs2025 = [
  _TaxSlab(upperLimit: 600000, fixedTax: 0, excessOver: 0, rate: 0),
  _TaxSlab(upperLimit: 1200000, fixedTax: 15000, excessOver: 600000, rate: 0.025),
  _TaxSlab(
    upperLimit: 2400000,
    fixedTax: 165000,
    excessOver: 1200000,
    rate: 0.125,
  ),
  _TaxSlab(
    upperLimit: 3600000,
    fixedTax: 435000,
    excessOver: 2400000,
    rate: 0.225,
  ),
  _TaxSlab(
    upperLimit: _infinity,
    fixedTax: 1095000,
    excessOver: 3600000,
    rate: 0.35,
  ),
];

const _salariedSlabs2024 = [
  _TaxSlab(upperLimit: 600000, fixedTax: 0, excessOver: 0, rate: 0),
  _TaxSlab(upperLimit: 1200000, fixedTax: 0, excessOver: 600000, rate: 0.025),
  _TaxSlab(
    upperLimit: 2400000,
    fixedTax: 15000,
    excessOver: 1200000,
    rate: 0.125, // This was correct
  ),
  _TaxSlab(
    upperLimit: 3600000,
    fixedTax: 165000,
    excessOver: 2400000,
    rate: 0.20,
  ),
  _TaxSlab(
    upperLimit: 6000000,
    fixedTax: 405000,
    excessOver: 3600000,
    rate: 0.25,
  ),
];

const _salariedSlabs2023 = [
  _TaxSlab(upperLimit: 600000, fixedTax: 0, excessOver: 0, rate: 0),
  _TaxSlab(upperLimit: 1200000, fixedTax: 0, excessOver: 600000, rate: 0.025),
  _TaxSlab(
    upperLimit: 2400000,
    fixedTax: 15000,
    excessOver: 1200000,
    rate: 0.125, // This was correct
  ),
  _TaxSlab(
    upperLimit: 3600000,
    fixedTax: 165000,
    excessOver: 2400000,
    rate: 0.20, // This was correct
  ),
  _TaxSlab(
    upperLimit: 6000000,
    fixedTax: 405000,
    excessOver: 3600000,
    rate: 0.25, // This was correct
  ),
  _TaxSlab(
    upperLimit: _infinity,
    fixedTax: 2955000,
    excessOver: 12000000,
    rate: 0.35,
  ),
];

const _salariedSlabs2021To2022 = [
  _TaxSlab(upperLimit: 600000, fixedTax: 0, excessOver: 0, rate: 0),
  _TaxSlab(upperLimit: 1200000, fixedTax: 0, excessOver: 600000, rate: 0.05),
  _TaxSlab(
    upperLimit: 1800000,
    fixedTax: 30000,
    excessOver: 1200000,
    rate: 0.10,
  ),
  _TaxSlab(
    upperLimit: 2500000,
    fixedTax: 90000,
    excessOver: 1800000,
    rate: 0.15,
  ),
  _TaxSlab(
    upperLimit: 3500000,
    fixedTax: 195000,
    excessOver: 2500000,
    rate: 0.175,
  ),
  _TaxSlab(
    upperLimit: 5000000,
    fixedTax: 370000,
    excessOver: 3500000,
    rate: 0.20,
  ),
  _TaxSlab(
    upperLimit: 8000000,
    fixedTax: 670000,
    excessOver: 5000000,
    rate: 0.225,
  ),
  _TaxSlab(
    upperLimit: 12000000,
    fixedTax: 1345000,
    excessOver: 8000000,
    rate: 0.25,
  ),
  _TaxSlab(
    upperLimit: 30000000,
    fixedTax: 2345000,
    excessOver: 12000000,
    rate: 0.275,
  ),
  _TaxSlab(
    upperLimit: 50000000,
    fixedTax: 7295000,
    excessOver: 30000000,
    rate: 0.30,
  ),
  _TaxSlab(
    upperLimit: 75000000,
    fixedTax: 13295000,
    excessOver: 50000000,
    rate: 0.325,
  ),
  _TaxSlab(
    upperLimit: _infinity,
    fixedTax: 21420000,
    excessOver: 75000000,
    rate: 0.35,
  ),
];

const _salariedSlabs2020 = [
  _TaxSlab(upperLimit: 600000, fixedTax: 0, excessOver: 0, rate: 0),
  _TaxSlab(upperLimit: 1200000, fixedTax: 0, excessOver: 600000, rate: 0.05),
  _TaxSlab(
    upperLimit: 1800000,
    fixedTax: 30000,
    excessOver: 1200000,
    rate: 0.10,
  ),
  _TaxSlab(
    upperLimit: 2500000,
    fixedTax: 90000,
    excessOver: 1800000,
    rate: 0.15,
  ),
  _TaxSlab(
    upperLimit: 3500000,
    fixedTax: 195000,
    excessOver: 2500000,
    rate: 0.175,
  ),
  _TaxSlab(
    upperLimit: 5000000,
    fixedTax: 370000,
    excessOver: 3500000,
    rate: 0.20,
  ),
  _TaxSlab(
    upperLimit: 8000000,
    fixedTax: 670000,
    excessOver: 5000000,
    rate: 0.225,
  ),
  _TaxSlab(
    upperLimit: 12000000,
    fixedTax: 1345000,
    excessOver: 8000000,
    rate: 0.25,
  ),
  _TaxSlab(
    upperLimit: _infinity,
    fixedTax: 2345000,
    excessOver: 12000000,
    rate: 0.275,
  ),
];

const _salariedSlabs2019 = [
  _TaxSlab(upperLimit: 400000, fixedTax: 0, excessOver: 0, rate: 0),
  _TaxSlab(upperLimit: 800000, fixedTax: 1000, excessOver: 400000, rate: 0),
  _TaxSlab(upperLimit: 1200000, fixedTax: 2000, excessOver: 800000, rate: 0),
  _TaxSlab(upperLimit: 2400000, fixedTax: 0, excessOver: 1200000, rate: 0.05),
  _TaxSlab(
    upperLimit: 4800000,
    fixedTax: 60000,
    excessOver: 2400000,
    rate: 0.10,
  ),
  _TaxSlab(
    upperLimit: _infinity,
    fixedTax: 300000,
    excessOver: 4800000,
    rate: 0.15,
  ),
];

const _salariedSlabs2018 = [
  _TaxSlab(upperLimit: 400000, fixedTax: 0, excessOver: 0, rate: 0),
  _TaxSlab(upperLimit: 500000, fixedTax: 0, excessOver: 400000, rate: 0.02),
  _TaxSlab(upperLimit: 750000, fixedTax: 2000, excessOver: 500000, rate: 0.05),
  _TaxSlab(
    upperLimit: 1400000,
    fixedTax: 14500,
    excessOver: 750000,
    rate: 0.10,
  ),
  _TaxSlab(
    upperLimit: 1500000,
    fixedTax: 79500,
    excessOver: 1400000,
    rate: 0.125,
  ),
  _TaxSlab(
    upperLimit: 1800000,
    fixedTax: 92000,
    excessOver: 1500000,
    rate: 0.15,
  ),
  _TaxSlab(
    upperLimit: 2500000,
    fixedTax: 137000,
    excessOver: 1800000,
    rate: 0.175,
  ),
  _TaxSlab(
    upperLimit: 3000000,
    fixedTax: 259500,
    excessOver: 2500000,
    rate: 0.20,
  ),
  _TaxSlab(
    upperLimit: 3500000,
    fixedTax: 359500,
    excessOver: 3000000,
    rate: 0.225,
  ),
  _TaxSlab(
    upperLimit: 4000000,
    fixedTax: 472000,
    excessOver: 3500000,
    rate: 0.25,
  ),
  _TaxSlab(
    upperLimit: 7000000,
    fixedTax: 597000,
    excessOver: 4000000,
    rate: 0.275,
  ),
  _TaxSlab(
    upperLimit: _infinity,
    fixedTax: 1422000,
    excessOver: 7000000,
    rate: 0.30,
  ),
];

const _salariedSlabs2017 = [
  _TaxSlab(upperLimit: 400000, fixedTax: 0, excessOver: 0, rate: 0),
  _TaxSlab(upperLimit: 500000, fixedTax: 0, excessOver: 400000, rate: 0.02),
  _TaxSlab(upperLimit: 750000, fixedTax: 2000, excessOver: 500000, rate: 0.05),
  _TaxSlab(
    upperLimit: 1400000,
    fixedTax: 14500,
    excessOver: 750000,
    rate: 0.10,
  ),
  _TaxSlab(
    upperLimit: 1500000,
    fixedTax: 79500,
    excessOver: 1400000,
    rate: 0.125,
  ),
  _TaxSlab(
    upperLimit: 1800000,
    fixedTax: 92000,
    excessOver: 1500000,
    rate: 0.15,
  ),
  _TaxSlab(
    upperLimit: 2500000,
    fixedTax: 137000,
    excessOver: 1800000,
    rate: 0.175,
  ),
  _TaxSlab(
    upperLimit: 3000000,
    fixedTax: 259500,
    excessOver: 2500000,
    rate: 0.20,
  ),
  _TaxSlab(
    upperLimit: _infinity,
    fixedTax: 359500,
    excessOver: 3000000,
    rate: 0.225,
  ),
];

const _salariedSlabsByTaxYear = {
  2027: _salariedSlabs2027,
  2026: _salariedSlabs2026,
  2025: _salariedSlabs2025,
  2024: _salariedSlabs2024,
  2023: _salariedSlabs2023,
  2022: _salariedSlabs2021To2022,
  2021: _salariedSlabs2021To2022,
  2020: _salariedSlabs2020,
  2019: _salariedSlabs2019,
  2018: _salariedSlabs2018,
  2017: _salariedSlabs2017,
};
