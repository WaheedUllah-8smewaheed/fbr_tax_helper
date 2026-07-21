package com.example.fbr_tax_helper

import android.app.Notification
import android.content.ComponentName
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.util.Locale

class NotificationCaptureService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        capture(sbn)
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        // Import matching notifications that are still present after Android
        // reconnects this listener, including while the Flutter app was closed.
        try {
            activeNotifications?.forEach(::capture)
        } catch (_: SecurityException) {
            // Android will call onNotificationPosted for subsequent alerts.
        }
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            requestRebind(ComponentName(this, NotificationCaptureService::class.java))
        }
    }

    private fun capture(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return

        val notification = sbn.notification ?: return
        val title = notification.extras
            ?.getCharSequence(Notification.EXTRA_TITLE)
            ?.toString()
            ?.trim()
            .orEmpty()
        val message = buildMessage(notification).trim()
        if (message.isBlank() || !shouldCapture(message)) return

        val item = JSONObject()
            .put("id", sbn.key)
            .put("packageName", sbn.packageName)
            .put("appName", appNameForPackage(sbn.packageName))
            .put("title", title)
            .put("message", message)
            .put("postedAt", sbn.postTime)

        NotificationInboxStore.add(applicationContext, item)
    }

    private fun buildMessage(notification: Notification): String {
        val extras = notification.extras ?: return ""
        val parts = linkedSetOf<String>()

        listOf(
            Notification.EXTRA_TITLE,
            Notification.EXTRA_TEXT,
            Notification.EXTRA_BIG_TEXT,
            Notification.EXTRA_SUB_TEXT,
            Notification.EXTRA_SUMMARY_TEXT
        ).forEach { key ->
            extras.getCharSequence(key)?.toString()?.trim()
                ?.takeIf { it.isNotBlank() }
                ?.let(parts::add)
        }

        extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.mapNotNull { it?.toString()?.trim() }
            ?.filter { it.isNotBlank() }
            ?.forEach(parts::add)

        return parts.joinToString(" ")
    }

    private fun shouldCapture(message: String): Boolean {
        val lower = message.lowercase(Locale.US)
        val hasCurrency = Regex("""\b(rs\.?|pkr)\b""").containsMatchIn(lower)
        val hasTransactionPattern =
            lower.contains("sent to") ||
                lower.contains("sent ") ||
                lower.contains("paid for") ||
                lower.contains("payment") ||
                lower.contains("purchase") ||
                lower.contains("transaction") ||
                lower.contains("transfer") ||
                lower.contains("debited") ||
                lower.contains("debit") ||
                lower.contains("withdrawn") ||
                lower.contains("withdrawal") ||
                lower.contains("credited") ||
                lower.contains("credit") ||
                lower.contains("deposited") ||
                lower.contains("deposit") ||
                lower.contains("received") ||
                lower.contains("recieved")

        return hasCurrency && hasTransactionPattern
    }

    private fun appNameForPackage(packageName: String): String {
        return try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            packageName
        }
    }
}
