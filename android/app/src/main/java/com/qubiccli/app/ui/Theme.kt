package com.qubiccli.app.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object QubicColors {
    val Accent = Color(0xFF7FEEDB)
    val Base = Color(0xFF0B1117)
    val Surface = Color(0xFF111921)
    val SurfaceHigh = Color(0xFF1A242D)
    val Hairline = Color(0x14FFFFFF) // white alpha ~6%
    val Text = Color(0xEBFFFFFF)     // ~92%
    val TextDim = Color(0x8CFFFFFF)  // ~55%
    val TextFaint = Color(0x59FFFFFF) // ~35%
    val Success = Color(0xFF4DF299)
    val Warn = Color(0xFFFFBF4D)
    val Danger = Color(0xFFFF7373)
}

private val DarkColors = darkColorScheme(
    primary = QubicColors.Accent,
    onPrimary = QubicColors.Base,
    secondary = QubicColors.Accent,
    onSecondary = QubicColors.Base,
    background = QubicColors.Base,
    onBackground = QubicColors.Text,
    surface = QubicColors.Surface,
    onSurface = QubicColors.Text,
    surfaceVariant = QubicColors.SurfaceHigh,
    onSurfaceVariant = QubicColors.TextDim,
    error = QubicColors.Danger,
    onError = QubicColors.Base,
)

@Composable
fun QubicTheme(content: @Composable () -> Unit) {
    // Always dark — mirrors iOS which is dark-only.
    @Suppress("UNUSED_VARIABLE") val isDark = isSystemInDarkTheme()
    MaterialTheme(
        colorScheme = DarkColors,
        content = content,
    )
}
