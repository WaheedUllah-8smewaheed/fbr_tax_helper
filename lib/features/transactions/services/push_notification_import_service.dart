import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:fbr_tax_helper/features/transactions/domain/entities/captured_push_notification.dart';

class PushNotificationImportService {
  const PushNotificationImportService();

  static const _channel = MethodChannel('fbr_tax_helper/notification_import');

  Future<bool> isNotificationAccessEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isNotificationAccessEnabled') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openNotificationAccessSettings() {
    return _channel.invokeMethod<void>('openNotificationAccessSettings');
  }

  Future<List<CapturedPushNotification>> getCapturedNotifications() async {
    String encoded;
    try {
      encoded =
          await _channel.invokeMethod<String>('getCapturedNotifications') ??
          '[]';
    } on MissingPluginException {
      encoded = '[]';
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map(
          (json) => CapturedPushNotification.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }

  Future<void> dismissNotification(String id) {
    return _channel.invokeMethod<void>('dismissNotification', {'id': id});
  }
}
