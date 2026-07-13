import 'package:fbr_tax_helper/features/transactions/services/receipt_scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts editable transaction details from common receipt text', () {
    const text = '''
Fresh Mart Lahore
Tax Invoice
Date: 12/07/2026
Grocery items
Grand Total PKR 1,245.50
''';

    final result = ReceiptScannerService.parseText(
      text,
      imagePath: 'receipt.jpg',
    );

    expect(result.merchant, 'Fresh Mart Lahore');
    expect(result.amount, 1245.50);
    expect(result.date, DateTime(2026, 7, 12));
    expect(result.suggestedCategory, 'Shopping');
    expect(result.purpose, 'Purchase from Fresh Mart Lahore');
  });

  test('prefers a labelled total over other receipt numbers', () {
    const text = '''
Corner Cafe
Invoice 82940
Subtotal 800.00
Grand Total 920.00
''';

    final result = ReceiptScannerService.parseText(
      text,
      imagePath: 'receipt.jpg',
    );

    expect(result.amount, 920);
    expect(result.suggestedCategory, 'Food & Drinks');
  });
}
