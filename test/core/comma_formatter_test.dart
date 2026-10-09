import 'package:fbr_tax_helper/core/utils/comma_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the cursor beside the edited digits after formatting', () {
    const formatter = CommaTextInputFormatter();
    const input = TextEditingValue(
      text: '129,345',
      selection: TextSelection.collapsed(offset: 3),
    );

    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: '12,345'),
      input,
    );

    expect(result.text, '129,345');
    expect(result.selection.extentOffset, 3);
  });

  test('integer-only mode removes decimal characters', () {
    const formatter = CommaTextInputFormatter(allowDecimal: false);
    const input = TextEditingValue(
      text: '12.345',
      selection: TextSelection.collapsed(offset: 6),
    );

    final result = formatter.formatEditUpdate(
      const TextEditingValue(),
      input,
    );

    expect(result.text, '12,345');
  });
}