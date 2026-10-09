import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CommaTextInputFormatter extends TextInputFormatter {
  const CommaTextInputFormatter({this.allowDecimal = true});

  final bool allowDecimal;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    
    final digitsAndDot = newValue.text.replaceAll(
      RegExp(allowDecimal ? r'[^0-9.]' : r'[^0-9]'),
      '',
    );
    if (digitsAndDot.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Ensure only one decimal point
    final parts = digitsAndDot.split('.');
    String integerPart = parts[0];
    String? decimalPart = allowDecimal && parts.length > 1
      ? parts.sublist(1).join('')
      : null;

    if (integerPart.isEmpty && decimalPart != null) {
      integerPart = '0';
    }

    String formattedInteger = '';
    if (integerPart.isNotEmpty) {
      final number = int.tryParse(integerPart);
      if (number != null) {
        final formatter = NumberFormat('#,###');
        formattedInteger = formatter.format(number);
      }
    }

    String newText = formattedInteger;
    if (parts.length > 1) {
      newText += '.$decimalPart';
    }

    final selectionEnd = newValue.selection.extentOffset
        .clamp(0, newValue.text.length)
        .toInt();
    final prefix = newValue.text
        .substring(0, selectionEnd)
        .replaceAll(RegExp(allowDecimal ? r'[^0-9.]' : r'[^0-9]'), '');
    final digitsBeforeSelection = prefix.replaceAll('.', '').length;
    final decimalBeforeSelection = allowDecimal && prefix.contains('.');
    var formattedSelection = 0;
    var digitsSeen = 0;

    for (var index = 0; index < newText.length; index++) {
      final character = newText[index];
      if (character == '.') {
        if (decimalBeforeSelection && digitsSeen == digitsBeforeSelection) {
          formattedSelection = index + 1;
          break;
        }
      } else if (RegExp(r'[0-9]').hasMatch(character)) {
        digitsSeen++;
        if (!decimalBeforeSelection && digitsSeen == digitsBeforeSelection) {
          formattedSelection = index + 1;
          break;
        }
      }
    }

    if (digitsBeforeSelection == 0 && !decimalBeforeSelection) {
      formattedSelection = 0;
    } else if (formattedSelection == 0) {
      formattedSelection = newText.length;
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: formattedSelection),
    );
  }
}
