package com.example.fbr_tax_helper

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.util.Locale

class NotificationCaptureService : NotificationListenerService() {
    companion object {
        @Volatile
        private var connectedService: NotificationCaptureService? = null

        fun isConnected(): Boolean = connectedService != null

        fun refreshActiveNotifications(): Boolean {
            val service = connectedService ?: return false
            service.captureActiveNotifications()
            return true
        }
    }

    override fun onDestroy() {
        if (connectedService === this) connectedService = null
        super.onDestroy()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        runCatching { capture(sbn) }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        // Import matching notifications that are still present after Android
        // reconnects this listener, including while the Flutter app was closed.
        connectedService = this
        captureActiveNotifications()
    }

    override fun onListenerDisconnected() {
        if (connectedService === this) connectedService = null
        super.onListenerDisconnected()
    }

    private fun captureActiveNotifications() {
        try {
            activeNotifications?.forEach { notification ->
                runCatching { capture(notification) }
            }
        } catch (_: SecurityException) {
            // Android will call onNotificationPosted for subsequent alerts.
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

        // Apps commonly reuse one Android notification key. Include event data
        // so later transactions remain distinct while active-notification
        // refreshes still produce the same identifier for the same alert.
        val eventId = "${sbn.key}|${sbn.postTime}|${message.hashCode()}"

        val item = JSONObject()
            .put("id", eventId)
            .put("sourceId", sbn.key)
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
        val lower = message
            .lowercase(Locale.US)
            .replace(Regex("""\s+"""), " ")
        val hasTransactionPattern =
            lower.contains("sent to") ||
                lower.contains("received from") ||
                lower.contains("recieved from") ||
                lower.contains("has been debited") ||
                lower.contains("is debited") ||
                lower.contains("has been credited") ||
                lower.contains("is credited") ||
                lower.contains("transferred") ||
                lower.contains("transfered") ||
                lower.contains("transfer") ||
                lower.contains("debited") ||
                lower.contains("credited") ||
                lower.contains("received") ||
                lower.contains("recieved")

        return hasTransactionPattern
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
