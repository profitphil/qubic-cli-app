package com.qubiccli.app.data

import kotlinx.serialization.Serializable

@Serializable
data class CommandArg(
    val name: String,
    val type: String,           // string | number | address | tick | hex | file | bool
    val required: Boolean,
    val hint: String? = null,
)

@Serializable
data class Command(
    val flag: String,
    val category: String,
    val description: String,
    val args: List<CommandArg> = emptyList(),
    val needsSeed: Boolean = false,
    val readOnly: Boolean = false,
) {
    val id: String get() = flag
}

@Serializable
data class CommandCategory(
    val name: String,
    val order: Int,
    val icon: String,
) {
    val id: String get() = name
}

@Serializable
data class ExecResponse(
    val stdout: String = "",
    val stderr: String = "",
    val exit_code: Int = 0,
    val duration_ms: Int = 0,
    val timed_out: Boolean = false,
)

@Serializable
data class UploadResponse(
    val path: String,
    val name: String,
    val size: Long,
)
