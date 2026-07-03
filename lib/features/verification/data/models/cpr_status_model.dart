class CprStatusModel {
  const CprStatusModel({
    required this.cprNumber,
    required this.status,
    this.amount,
    this.bankName,
    this.taxPeriod,
    this.paidAt,
    required this.updatedAt,
  });

  final String cprNumber;
  final String status;
  final double? amount;
  final String? bankName;
  final String? taxPeriod;
  final DateTime? paidAt;
  final DateTime updatedAt;

  bool get isCleared => status.toUpperCase() == 'CLEARED';
  bool get isFailed => status.toUpperCase() == 'FAILED';

  factory CprStatusModel.fromJson(Map<String, dynamic> json) {
    return CprStatusModel(
      cprNumber: json['cprNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      amount: _readDouble(json['amount']),
      bankName: json['bankName']?.toString(),
      taxPeriod: json['taxPeriod']?.toString(),
      paidAt: DateTime.tryParse(json['paidAt']?.toString() ?? ''),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static double? _readDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
