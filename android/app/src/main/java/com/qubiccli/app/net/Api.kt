package com.qubiccli.app.net

import com.qubiccli.app.data.ExecResponse
import com.qubiccli.app.data.Settings
import com.qubiccli.app.data.UploadResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class ApiException(message: String) : Exception(message)

class Api(private val settings: Settings) {
    private val json = Json { ignoreUnknownKeys = true }
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(120, TimeUnit.SECONDS)
        .build()

    private fun baseOrThrow(): String {
        val b = settings.baseURL.trim()
        if (b.isEmpty() || settings.token.isEmpty()) {
            throw ApiException("Set API base URL and token in Settings.")
        }
        return b
    }

    suspend fun exec(args: List<String>, timeoutSec: Int = 60): ExecResponse = withContext(Dispatchers.IO) {
        val base = baseOrThrow()

        // auto-inject -nodeip / -nodeport if user set them and command didn't.
        // qubic-cli requires basic config BEFORE the command flag, so prepend.
        val finalArgs = args.toMutableList()
        if (settings.nodePort.isNotEmpty() && !finalArgs.contains("-nodeport")) {
            finalArgs.add(0, settings.nodePort)
            finalArgs.add(0, "-nodeport")
        }
        if (settings.nodeIP.isNotEmpty() && !finalArgs.contains("-nodeip")) {
            finalArgs.add(0, settings.nodeIP)
            finalArgs.add(0, "-nodeip")
        }

        val body = buildJsonObject {
            put("args", buildJsonArray { finalArgs.forEach { add(JsonPrimitive(it)) } })
            put("timeout_sec", JsonPrimitive(timeoutSec))
        }.toString()

        val req = Request.Builder()
            .url("$base/exec")
            .addHeader("Authorization", "Bearer ${settings.token}")
            .post(body.toRequestBody("application/json".toMediaType()))
            .build()

        client.newCall(req).execute().use { resp ->
            val text = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw ApiException("HTTP ${resp.code}: $text")
            try {
                json.decodeFromString(ExecResponse.serializer(), text)
            } catch (e: Exception) {
                throw ApiException("Decode: ${e.message}")
            }
        }
    }

    suspend fun upload(bytes: ByteArray, filename: String): UploadResponse = withContext(Dispatchers.IO) {
        val base = baseOrThrow()
        val safeName = filename.replace("\"", "")
        val body = MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart(
                "file",
                safeName,
                bytes.toRequestBody("application/octet-stream".toMediaType()),
            )
            .build()

        val req = Request.Builder()
            .url("$base/upload")
            .addHeader("Authorization", "Bearer ${settings.token}")
            .post(body)
            .build()

        client.newCall(req).execute().use { resp ->
            val text = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw ApiException("HTTP ${resp.code}: $text")
            try {
                json.decodeFromString(UploadResponse.serializer(), text)
            } catch (e: Exception) {
                throw ApiException("Decode: ${e.message}")
            }
        }
    }

    suspend fun health(): Boolean = withContext(Dispatchers.IO) {
        val base = settings.baseURL.trim()
        if (base.isEmpty()) return@withContext false
        val req = Request.Builder().url("$base/healthz").get().build()
        runCatching { client.newCall(req).execute().use { it.isSuccessful } }.getOrDefault(false)
    }
}
