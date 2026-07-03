class AtlStatusModel {
  const AtlStatusModel({
    required this.cnic,
    required this.status,
    this.taxpayerName,
    required this.atlPublishDate,
    required this.verifiedAt,
    required this.source,
  });

  final String cnic;
  final String status;
  final String? taxpayerName;
  final DateTime atlPublishDate;
  final DateTime verifiedAt;
  final String source;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isNotFound => status.toUpperCase() == 'NOT_FOUND';

  factory AtlStatusModel.fromJson(Map<String, dynamic> json) {
    return AtlStatusModel(
      cnic: json['cnic']?.toString() ?? '',
      status: json['status']?.toString() ?? 'NOT_FOUND',
      taxpayerName: json['taxpayerName']?.toString(),
      atlPublishDate:
          DateTime.tryParse(json['atlPublishDate']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      verifiedAt:
          DateTime.tryParse(json['verifiedAt']?.toString() ?? '') ??
          DateTime.now(),
      source: json['source']?.toString() ?? 'live',
    );
  }
}
