package com.qubiccli.app.data

import android.content.Context
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.UUID

@Serializable
data class HistoryEntry(
    val id: String = UUID.randomUUID().toString(),
    val date: Long = System.currentTimeMillis(),
    val flag: String,
    val args: List<String>,
    val exitCode: Int,
    val stdoutHead: String,
)

class History(private val context: Context) {
    private val prefs = context.getSharedPreferences("qubic_history", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }
    private val maxEntries = 100

    val entries = mutableStateListOf<HistoryEntry>()
    val favorites = mutableStateOf<Set<String>>(emptySet())

    init {
        val raw = prefs.getString("entries", null)
        if (raw != null) {
            runCatching { json.decodeFromString<List<HistoryEntry>>(raw) }
                .getOrNull()
                ?.let { entries.addAll(it) }
        }
        val favs = prefs.getStringSet("favorites", emptySet()) ?: emptySet()
        favorites.value = favs.toSet()
    }

    fun record(flag: String, args: List<String>, response: ExecResponse) {
        val redacted = redact(args)
        val head = response.stdout.take(2048)
        val entry = HistoryEntry(
            flag = flag,
            args = redacted,
            exitCode = response.exit_code,
            stdoutHead = head,
        )
        entries.add(0, entry)
        while (entries.size > maxEntries) entries.removeAt(entries.size - 1)
        save()
    }

    fun toggleFavorite(flag: String) {
        val cur = favorites.value.toMutableSet()
        if (!cur.add(flag)) cur.remove(flag)
        favorites.value = cur
        prefs.edit().putStringSet("favorites", cur).apply()
    }

    fun isFavorite(flag: String): Boolean = favorites.value.contains(flag)

    private fun save() {
        val serializer = kotlinx.serialization.builtins.ListSerializer(HistoryEntry.serializer())
        val s = json.encodeToString(serializer, entries.toList())
        prefs.edit().putString("entries", s).apply()
    }

    private fun redact(args: List<String>): List<String> {
        val out = args.toMutableList()
        var i = 0
        while (i < out.size) {
            if (out[i] == "-seed" && i + 1 < out.size) out[i + 1] = "[redacted]"
            i++
        }
        return out
    }
}
