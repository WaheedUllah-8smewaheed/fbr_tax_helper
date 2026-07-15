import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ReceiptScanResult {
  const ReceiptScanResult({
    required this.imagePath,
    required this.rawText,
    this.merchant,
    this.amount,
    this.date,
    this.purpose,
    this.suggestedCategory,
  });

  final String imagePath;
  final String rawText;
  final String? merchant;
  final double? amount;
  final DateTime? date;
  final String? purpose;
  final String? suggestedCategory;
}

class ReceiptScannerService {
  ReceiptScannerService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  Future<ReceiptScanResult?> captureAndScan(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2200,
    );
    if (picked == null) return null;

    final storedPath = await _storeReceipt(picked);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(storedPath),
      );
      return parseText(recognized.text, imagePath: storedPath);
    } finally {
      await recognizer.close();
    }
  }

  Future<String> _storeReceipt(XFile picked) async {
    final documents = await getApplicationDocumentsDirectory();
    final receiptDirectory = Directory(
      path.join(documents.path, 'transaction_receipts'),
    );
    await receiptDirectory.create(recursive: true);
    final extension = path.extension(picked.path).isEmpty
        ? '.jpg'
        : path.extension(picked.path);
    final destination = path.join(
      receiptDirectory.path,
      'receipt_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    return (await File(picked.path).copy(destination)).path;
  }

  static ReceiptScanResult parseText(
    String rawText, {
    required String imagePath,
  }) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final merchant = _findMerchant(lines);
    return ReceiptScanResult(
      imagePath: imagePath,
      rawText: rawText,
      merchant: merchant,
      amount: _findAmount(lines),
      date: _findDate(rawText),
      purpose: merchant == null
          ? 'Receipt purchase'
          : 'Purchase from $merchant',
      suggestedCategory: _inferCategory(rawText),
    );
  }

  static String? _findMerchant(List<String> lines) {
    final ignored = RegExp(
      r'^(receipt|invoice|tax invoice|cash memo|date|time|phone|tel|total|subtotal|amount|qty)\b',
      caseSensitive: false,
    );
    for (final line in lines.take(8)) {
      if (line.length >= 3 &&
          line.length <= 60 &&
          RegExp(r'[A-Za-z]{2}').hasMatch(line) &&
          !ignored.hasMatch(line)) {
        return line;
      }
    }
    return null;
  }

  static double? _findAmount(List<String> lines) {
    final preferred = lines.where(
      (line) => RegExp(
        r'\b(grand\s*total|net\s*total|amount\s*due|total)\b',
        caseSensitive: false,
      ).hasMatch(line),
    );
    for (final line in preferred.toList().reversed) {
      final values = _moneyValues(line);
      if (values.isNotEmpty) return values.last;
    }

    final candidates = lines.expand(_moneyValues).where((value) => value > 0);
    if (candidates.isEmpty) return null;
    return candidates.reduce(
      (largest, value) => value > largest ? value : largest,
    );
  }

  static List<double> _moneyValues(String text) {
    final matches = RegExp(
      r'(?:PKR|RS\.?|₨)?\s*([0-9]+(?:[ ,][0-9]{3})*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).allMatches(text);
    return matches
        .map((match) => match.group(1)!.replaceAll(RegExp(r'[ ,]'), ''))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
  }

  static DateTime? _findDate(String text) {
    final match = RegExp(
      r'\b(\d{1,2}[-/.]\d{1,2}[-/.](?:\d{2}|\d{4}))\b',
    ).firstMatch(text);
    final value = match?.group(1);
    if (value == null) return null;
    final normalized = value.replaceAll(RegExp(r'[-.]'), '/');
    for (final pattern in ['dd/MM/yyyy', 'd/M/yyyy', 'dd/MM/yy', 'd/M/yy']) {
      try {
        final parsed = DateFormat(pattern).parseStrict(normalized);
        if (!parsed.isAfter(DateTime.now())) return parsed;
      } on FormatException {
        // Try the next common receipt date format.
      }
    }
    return null;
  }

  static String _inferCategory(String text) {
    final lower = text.toLowerCase();
    if (_containsAny(lower, [
      'restaurant',
      'cafe',
      'food',
      'burger',
      'pizza',
    ])) {
      return 'Food & Drinks';
    }
    if (_containsAny(lower, ['hospital', 'clinic', 'pharmacy', 'medical'])) {
      return 'Health';
    }
    if (_containsAny(lower, ['rent', 'landlord', 'tenant'])) {
      return 'Rent';
    }
    if (_containsAny(lower, [
      'transport',
      'fuel',
      'petrol',
      'diesel',
      'taxi',
      'bus fare',
    ])) {
      return 'Transport';
    }
    if (_containsAny(lower, ['electric', 'gas bill', 'water bill'])) {
      return 'Housing & Utils';
    }
    if (_containsAny(lower, ['salon', 'spa', 'cosmetic'])) {
      return 'Personal Care';
    }
    if (_containsAny(lower, ['subscription', 'monthly plan', 'membership'])) {
      return 'Subscriptions';
    }
    if (_containsAny(lower, ['mart', 'store', 'shop', 'mall'])) {
      return 'Shopping';
    }
    return 'Misc';
  }

  static bool _containsAny(String text, List<String> values) {
    return values.any(text.contains);
  }
}
