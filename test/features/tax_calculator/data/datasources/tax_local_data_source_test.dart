import 'package:flutter_test/flutter_test.dart';
import 'package:fbr_tax_helper/features/tax_calculator/data/models/tax_profile_model.dart';
import 'package:fbr_tax_helper/features/tax_calculator/domain/entities/tax_profile.dart';

void main() {
  test('should accurately parse raw data maps back into system models', () {
    final jsonSampleMap = <String, dynamic>{
      'type': 'salaried',
      'monthlyGrossIncome': 120000.0,
      'taxYear': 2025,
    };

    final result = TaxProfileModel.fromMap(jsonSampleMap);

    expect(result.type, TaxProfileType.salaried);
    expect(result.monthlyGrossIncome, 120000.0);
    expect(result.taxYear, '2025');
    expect(result.toMap()['taxYear'], '2025');
  });
}
