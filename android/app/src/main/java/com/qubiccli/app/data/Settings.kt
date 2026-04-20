package com.qubiccli.app.data

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Mirrors iOS Settings: baseURL/nodeIP/nodePort in plain prefs, token+seed in
 * EncryptedSharedPreferences (AndroidKeyStore-backed).
 */
class Settings(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("qubic_prefs", Context.MODE_PRIVATE)

    private val secure: SharedPreferences = run {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            "qubic_secure",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.ValueEncryptionScheme.AES256_GCM,
        )
    }

    var baseURL by mutableStateOf(prefs.getString("baseURL", "") ?: "")
    var nodeIP by mutableStateOf(prefs.getString("nodeIP", "") ?: "")
    var nodePort by mutableStateOf(prefs.getString("nodePort", "21841") ?: "21841")

    var token by mutableStateOf(secure.getString("api.token", "") ?: "")
    var seed by mutableStateOf(secure.getString("qubic.seed", "") ?: "")

    fun persistBaseURL(v: String) { baseURL = v; prefs.edit().putString("baseURL", v).apply() }
    fun persistNodeIP(v: String)  { nodeIP = v;  prefs.edit().putString("nodeIP", v).apply() }
    fun persistNodePort(v: String){ nodePort = v; prefs.edit().putString("nodePort", v).apply() }

    fun persistToken(v: String) { token = v; secure.edit().putString("api.token", v).apply() }
    fun persistSeed(v: String)  { seed = v;  secure.edit().putString("qubic.seed", v).apply() }
}
