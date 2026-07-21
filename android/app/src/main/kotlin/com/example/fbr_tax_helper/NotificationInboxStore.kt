package com.example.fbr_tax_helper

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object NotificationInboxStore {
    private const val PREFS_NAME = "filer_flow_notification_imports"
    private const val ITEMS_KEY = "items"
    private const val MAX_ITEMS = 100

    fun getJson(context: Context): String {
        return prefs(context).getString(ITEMS_KEY, "[]") ?: "[]"
    }

    @Synchronized
    fun add(context: Context, item: JSONObject) {
        val id = item.optString("id")
        if (id.isBlank()) return

        val current = JSONArray(getJson(context))
        val updated = JSONArray()
        updated.put(item)

        for (index in 0 until current.length()) {
            val existing = current.optJSONObject(index) ?: continue
            if (existing.optString("id") == id) continue
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

        for (index in 0 until current.length()) {
            val existing = current.optJSONObject(index) ?: continue
            if (existing.optString("id") == id) continue
            updated.put(existing)
        }

        prefs(context).edit().putString(ITEMS_KEY, updated.toString()).commit()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
