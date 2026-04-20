package com.qubiccli.app.data

import android.content.Context
import kotlinx.serialization.json.Json

class Catalog(context: Context) {
    val commands: List<Command>
    val categories: List<CommandCategory>

    private val json = Json { ignoreUnknownKeys = true }

    init {
        commands = loadJson(context, "commands.json")
        categories = loadJson(context, "categories.json")
    }

    private inline fun <reified T> loadJson(context: Context, asset: String): List<T> {
        return try {
            val text = context.assets.open(asset).bufferedReader().use { it.readText() }
            json.decodeFromString(text)
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun commandsIn(category: String): List<Command> =
        commands.filter { it.category == category }.sortedBy { it.flag }

    fun search(query: String): List<Command> {
        val q = query.lowercase()
        if (q.isBlank()) return emptyList()
        return commands.filter {
            it.flag.lowercase().contains(q) || it.description.lowercase().contains(q)
        }
    }
}
