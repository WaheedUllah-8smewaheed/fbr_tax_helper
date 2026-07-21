import 'package:equatable/equatable.dart';

import 'package:fbr_tax_helper/features/transactions/services/notification_transaction_parser.dart';

class CapturedPushNotification extends Equatable {
  const CapturedPushNotification({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.title,
    required this.message,
    required this.postedAt,
  });

  factory CapturedPushNotification.fromJson(Map<String, dynamic> json) {
    return CapturedPushNotification(
      id: json['id'] as String? ?? '',
      packageName: json['packageName'] as String? ?? '',
      appName: json['appName'] as String? ?? 'Unknown app',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      postedAt: DateTime.fromMillisecondsSinceEpoch(
        json['postedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  final String id;
  final String packageName;
  final String appName;
  final String title;
  final String message;
  final DateTime postedAt;

  NotificationTransactionDetails? get details =>
      NotificationTransactionParser.parse(message);

  @override
  List<Object?> get props => [
    id,
    packageName,
    appName,
    title,
    message,
    postedAt,
  ];
}
