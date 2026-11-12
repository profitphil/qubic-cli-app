package com.qubiccli.app.data

/** Qubic identity (60 chars A–Z) → 32-byte public key as 64-char lowercase hex. */
object QubicIdentity {
    fun isIdentity(s: String) = s.length == 60 && s.all { it in 'A'..'Z' }

    fun publicKeyHex(identity: String): String? {
        if (!isIdentity(identity)) return null
        val sb = StringBuilder()
        for (i in 0 until 4) {
            var v = 0L // wraps as unsigned 64-bit
            for (j in 13 downTo 0) v = v * 26L + (identity[i * 14 + j] - 'A').toLong()
            for (b in 0 until 8) sb.append("%02x".format(((v ushr (8 * b)) and 0xff).toInt()))
        }
        return sb.toString()
    }

    /** For `hex` args: convert a 60-char identity, otherwise pass through unchanged. */
    fun normalizeHexArg(value: String) = publicKeyHex(value) ?: value
}
