import 'package:fbr_tax_helper/core/validation/fbr_validators.dart';
import 'package:fbr_tax_helper/features/verification/data/models/atl_status_model.dart';
import 'package:fbr_tax_helper/features/verification/data/models/cpr_status_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats and validates CNIC values', () {
    expect(CnicValidator.normalize('3520212345671'), '35202-1234567-1');
    expect(CnicValidator.validate('35202-1234567-1'), isNull);
    expect(CnicValidator.validate('3520212345671'), isNotNull);
  });

  test('parses active ATL status payload', () {
    final model = AtlStatusModel.fromJson({
      'cnic': '35202-1234567-1',
      'status': 'ACTIVE',
      'taxpayerName': 'Test Taxpayer',
      'atlPublishDate': '2026-07-01T00:00:00.000Z',
      'verifiedAt': '2026-07-03T10:30:00.000Z',
      'source': 'cache',
    });

    expect(model.isActive, isTrue);
    expect(model.taxpayerName, 'Test Taxpayer');
    expect(model.source, 'cache');
  });

  test('parses cleared CPR status payload', () {
    final model = CprStatusModel.fromJson({
      'cprNumber': 'CPR-123',
      'status': 'CLEARED',
      'amount': '15000',
      'bankName': 'Test Bank',
      'updatedAt': '2026-07-03T10:30:00.000Z',
    });

    expect(model.isCleared, isTrue);
    expect(model.amount, 15000);
    expect(model.bankName, 'Test Bank');
  });
}
