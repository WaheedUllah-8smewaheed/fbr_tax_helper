class NtnProfileModel {
  const NtnProfileModel({
    required this.ntn,
    required this.businessName,
    required this.operationalStatus,
    required this.rto,
    this.registrationDate,
    required this.fetchedAt,
  });

  final String ntn;
  final String businessName;
  final String operationalStatus;
  final String rto;
  final DateTime? registrationDate;
  final DateTime fetchedAt;

  factory NtnProfileModel.fromJson(Map<String, dynamic> json) {
    return NtnProfileModel(
      ntn: json['ntn']?.toString() ?? '',
      businessName: json['businessName']?.toString() ?? '',
      operationalStatus: json['operationalStatus']?.toString() ?? 'UNKNOWN',
      rto: json['rto']?.toString() ?? '',
      registrationDate: DateTime.tryParse(
        json['registrationDate']?.toString() ?? '',
      ),
      fetchedAt:
          DateTime.tryParse(json['fetchedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
