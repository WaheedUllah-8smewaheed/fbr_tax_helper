import 'package:flutter/services.dart';

class CnicValidator {
  const CnicValidator._();

  static final _pattern = RegExp(r'^\d{5}-\d{7}-\d{1}$');

  static String? validate(String? value) {
    final cleaned = (value ?? '').replaceAll(RegExp(r'\s'), '');
    if (!_pattern.hasMatch(cleaned)) {
      return 'Enter CNIC in format 00000-0000000-0';
    }
    return null;
  }

  static String normalize(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) return value.trim();
    return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12)}';
  }
}

class CprValidator {
  const CprValidator._();

  static String? validate(String? value) {
    final cleaned = (value ?? '').trim();
    if (cleaned.length < 6) return 'Enter a valid CPR number';
    if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(cleaned)) {
      return 'Use only letters, numbers, and dashes';
    }
    return null;
  }
}

class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 13 ? digits.substring(0, 13) : digits;
    final buffer = StringBuffer();

    for (var index = 0; index < limited.length; index++) {
      if (index == 5 || index == 12) buffer.write('-');
      buffer.write(limited[index]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
