import 'package:fbr_tax_helper/features/transactions/domain/entities/transaction_category.dart';

class NotificationTransactionDetails {
  const NotificationTransactionDetails({
    required this.amount,
    required this.isExpense,
    required this.title,
    required this.beneficiary,
    required this.purpose,
    required this.category,
  });

  final double? amount;
  final bool isExpense;
  final String title;
  final String beneficiary;
  final String purpose;
  final String category;
}

class NotificationTransactionParser {
  const NotificationTransactionParser._();

  static NotificationTransactionDetails? parse(String rawMessage) {
    final message = _normalize(rawMessage);
    if (message.isEmpty || !_hasCurrencyMarker(message)) return null;

    return _parseReceived(message) ??
        _parseSent(message) ??
        _parsePaidFor(message) ??
        _parseBankAlert(message);
  }

  static NotificationTransactionDetails? _parseBankAlert(String message) {
    final lower = message.toLowerCase();
    final isIncome = RegExp(
      r'\b(received|recieved|credited|credit|deposited|deposit)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    final isExpense = RegExp(
      r'\b(sent|paid|payment|purchase|debited|debit|withdrawn|withdrawal|spent|transferred|transfer)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    if (!isIncome && !isExpense) return null;

    final expense = !isIncome;
    final party = _extractParty(message, isExpense: expense);
    final purpose = expense ? 'Payment notification' : 'Received payment';
    return NotificationTransactionDetails(
      amount: _extractAmount(message),
      isExpense: expense,
      title: party.isEmpty
          ? expense
                ? 'Payment notification'
                : 'Received payment'
          : expense
          ? 'Payment to $party'
          : 'Received from $party',
      beneficiary: party,
      purpose: purpose,
      category: TransactionCategory.misc.name,
    );
  }

  static NotificationTransactionDetails? _parseSent(String message) {
    final match = RegExp(
      r'\b(?:rs\.?|pkr)\s*([0-9][0-9,]*(?:\.\d+)?)?\s*sent\s+to\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(message);
    if (match == null) return null;

    final sentTail = _cleanTail(match.group(2) ?? '');
    final beneficiary = _firstNameFromSentTail(sentTail);
    final titleTail = _titleFromSentTail(sentTail);
    return NotificationTransactionDetails(
      amount: _parseAmount(match.group(1)),
      isExpense: true,
      title: titleTail.isNotEmpty
          ? titleTail
          : beneficiary.isEmpty
          ? 'Sent payment'
          : 'Sent to $beneficiary',
      beneficiary: beneficiary,
      purpose: 'Sent payment',
      category: TransactionCategory.misc.name,
    );
  }

  static NotificationTransactionDetails? _parsePaidFor(String message) {
    final match = RegExp(
      r'\b(?:rs\.?|pkr)\s*([0-9][0-9,]*(?:\.\d+)?)?\s*paid\s+for\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(message);
    if (match == null) return null;

    final paidFor = match.group(2) ?? '';
    final splitMatch = RegExp(
      r'^(.+?)(?:,\s*for\s+|\s+for\s+)(.+?)(?:\s+on\s+|,|$)',
      caseSensitive: false,
    ).firstMatch(paidFor);
    final purpose = _cleanTail(splitMatch?.group(1) ?? paidFor);
    final beneficiary = _cleanTail(splitMatch?.group(2) ?? '');

    return NotificationTransactionDetails(
      amount: _parseAmount(match.group(1)),
      isExpense: true,
      title: purpose.isEmpty ? 'Paid transaction' : 'Paid for $purpose',
      beneficiary: beneficiary,
      purpose: purpose.isEmpty ? 'Paid transaction' : purpose,
      category: TransactionCategory.misc.name,
    );
  }

  static NotificationTransactionDetails? _parseReceived(String message) {
    final beforeVerb = RegExp(
      r'\b(?:rs\.?|pkr)\s*([0-9][0-9,]*(?:\.\d+)?)?\s*(?:received|recieved)\s+from\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(message);
    final afterVerb = RegExp(
      r'\b(?:received|recieved)\s*(?:rs\.?|pkr)?\s*([0-9][0-9,]*(?:\.\d+)?)?\s*from\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(message);
    final match = beforeVerb ?? afterVerb;
    if (match == null) return null;

    final beneficiary = _cleanTail(match.group(2) ?? '');
    return NotificationTransactionDetails(
      amount: _parseAmount(match.group(1)),
      isExpense: false,
      title: beneficiary.isEmpty
          ? 'Received payment'
          : 'Received from $beneficiary',
      beneficiary: beneficiary,
      purpose: 'Received payment',
      category: TransactionCategory.misc.name,
    );
  }

  static bool _hasCurrencyMarker(String message) {
    return RegExp(r'\b(?:rs\.?|pkr)\b', caseSensitive: false).hasMatch(message);
  }

  static String _normalize(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('\u00a0', ' ')
        .trim();
  }

  static String _cleanTail(String value) {
    var cleaned = value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.،,]+$'), '')
        .trim();
    cleaned = cleaned.replaceFirst(
      RegExp(r'\s+(?:on|in|at)\s+.*$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceFirst(
      RegExp(r'\s+(?:on|in|at)$', caseSensitive: false),
      '',
    );
    return cleaned.trim();
  }

  static String _firstNameFromSentTail(String value) {
    final beforeComma = value.split(',').first.trim();
    final match = RegExp(r'^\S+').firstMatch(beforeComma);
    return match?.group(0)?.trim() ?? '';
  }

  static String _titleFromSentTail(String value) {
    final commaIndex = value.indexOf(',');
    if (commaIndex < 0 || commaIndex == value.length - 1) return '';
    return _cleanTail(value.substring(commaIndex + 1));
  }

  static double? _parseAmount(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.replaceAll(',', '').trim());
  }

  static double? _extractAmount(String message) {
    final afterCurrency = RegExp(
      r'\b(?:rs\.?|pkr)\s*[:\-]?\s*([0-9][0-9,]*(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(message);
    final beforeCurrency = RegExp(
      r'\b([0-9][0-9,]*(?:\.\d+)?)\s*(?:rs\.?|pkr)\b',
      caseSensitive: false,
    ).firstMatch(message);
    return _parseAmount(afterCurrency?.group(1) ?? beforeCurrency?.group(1));
  }

  static String _extractParty(String message, {required bool isExpense}) {
    final expression = isExpense
        ? RegExp(
            r'\b(?:to|at)\s+(.+?)(?=\s+(?:on|ref|reference|txn|transaction\s+id)\b|[,.;]|$)',
            caseSensitive: false,
          )
        : RegExp(
            r'\bfrom\s+(.+?)(?=\s+(?:on|ref|reference|txn|transaction\s+id)\b|[,.;]|$)',
            caseSensitive: false,
          );
    return _cleanTail(expression.firstMatch(message)?.group(1) ?? '');
  }
}
