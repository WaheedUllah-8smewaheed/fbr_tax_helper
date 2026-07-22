package com.example.fbr_tax_helper

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object NotificationInboxStore {
    private const val PREFS_NAME = "filer_flow_notification_imports"
    private const val ITEMS_KEY = "items"
    private const val HANDLED_KEY = "handled_events"
    private const val MAX_ITEMS = 100
    private const val MAX_HANDLED_EVENTS = 500

    fun getJson(context: Context): String {
        return prefs(context).getString(ITEMS_KEY, "[]") ?: "[]"
    }

    @Synchronized
    fun add(context: Context, item: JSONObject) {
        val id = item.optString("id")
        if (id.isBlank()) return
        if (isHandled(context, item)) return

        val current = JSONArray(getJson(context))
        val updated = JSONArray()
        updated.put(item)

        for (index in 0 until current.length()) {
            val existing = current.optJSONObject(index) ?: continue
            if (existing.optString("id") == id || sameEvent(existing, item)) continue
            if (updated.length() >= MAX_ITEMS) break
            updated.put(existing)
        }

        // Commit synchronously because this listener may be stopped immediately
        // after Android delivers a notification while the main app is closed.
        prefs(context).edit().putString(ITEMS_KEY, updated.toString()).commit()
    }

    @Synchronized
    fun dismiss(context: Context, id: String) {
        val current = JSONArray(getJson(context))
        val updated = JSONArray()
        val newlyHandled = mutableListOf<String>()

        for (index in 0 until current.length()) {
            val existing = current.optJSONObject(index) ?: continue
            if (existing.optString("id") == id) {
                newlyHandled.add(fingerprint(existing))
                continue
            }
            updated.put(existing)
        }

        val handled = JSONArray(
            prefs(context).getString(HANDLED_KEY, "[]") ?: "[]"
        )
        val mergedHandled = JSONArray()
        for (handledEvent in newlyHandled) {
            mergedHandled.put(handledEvent)
        }
        for (index in 0 until handled.length()) {
            if (mergedHandled.length() >= MAX_HANDLED_EVENTS) break
            val existing = handled.optString(index)
            if (existing.isBlank() || newlyHandled.contains(existing)) continue
            mergedHandled.put(existing)
        }

        prefs(context).edit()
            .putString(ITEMS_KEY, updated.toString())
            .putString(HANDLED_KEY, mergedHandled.toString())
            .commit()
    }

    private fun isHandled(context: Context, item: JSONObject): Boolean {
        val target = fingerprint(item)
        val handled = JSONArray(
            prefs(context).getString(HANDLED_KEY, "[]") ?: "[]"
        )
        for (index in 0 until handled.length()) {
            if (handled.optString(index) == target) return true
        }
        return false
    }

    private fun fingerprint(item: JSONObject): String {
        val packageName = item.optString("packageName")
        val postedAt = item.optLong("postedAt")
        val messageHash = item.optString("message").hashCode()
        return "$packageName|$postedAt|$messageHash"
    }

    private fun sameEvent(first: JSONObject, second: JSONObject): Boolean {
        return fingerprint(first) == fingerprint(second)
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
