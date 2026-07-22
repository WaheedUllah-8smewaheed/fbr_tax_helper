package com.example.fbr_tax_helper

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun onResume() {
        super.onResume()
        requestNotificationListenerRebindIfNeeded()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fbr_tax_helper/notification_import"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessEnabled" -> {
                    result.success(isNotificationAccessEnabled())
                }
                "openNotificationAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "getCapturedNotifications" -> {
                    result.success(NotificationInboxStore.getJson(this))
                }
                "refreshNotificationListener" -> {
                    val connected = NotificationCaptureService
                        .refreshActiveNotifications()
                    if (!connected) requestNotificationListenerRebindIfNeeded()
                    result.success(connected)
                }
                "dismissNotification" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error(
                            "missing_id",
                            "Notification id is required.",
                            null
                        )
                    } else {
                        NotificationInboxStore.dismiss(this, id)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isNotificationAccessEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        val listener = ComponentName(
            this,
            NotificationCaptureService::class.java
        ).flattenToString()

        return enabled.split(":").any {
            it.equals(listener, ignoreCase = true) ||
                it.contains(packageName, ignoreCase = true)
        }
    }

    private fun requestNotificationListenerRebindIfNeeded() {
        if (!isNotificationAccessEnabled() ||
            Build.VERSION.SDK_INT < Build.VERSION_CODES.N ||
            NotificationCaptureService.isConnected()
        ) return

        NotificationListenerService.requestRebind(
            ComponentName(this, NotificationCaptureService::class.java)
        )
    }
}
