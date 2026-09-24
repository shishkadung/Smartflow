package com.urbiztondo.smartflow.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object Sf {
    val Bg = Color(0xFFF4F7FF)
    val Paper = Color(0xFFFFFFFF)
    val Ink = Color(0xFF0F172A)
    val Muted = Color(0x9E0F172A)
    val Blue = Color(0xFF1D4ED8)
    val Blue2 = Color(0xFF4A6CF7)
    val Gold = Color(0xFFE0B84F)
    val Green = Color(0xFF16A34A)
    val Red = Color(0xFFDC2626)

    fun dept(code: String): Color = when (code.uppercase()) {
        "ENG" -> Color(0xFF2563EB)
        "HR" -> Color(0xFF7C3AED)
        "BUD" -> Color(0xFF059669)
        else -> Color(0xFFD97706)
    }
}

private val scheme = lightColorScheme(
    primary = Sf.Blue,
    onPrimary = Color.White,
    background = Sf.Bg,
    surface = Sf.Paper,
    onSurface = Sf.Ink,
)

@Composable
fun SmartflowTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = scheme, content = content)
}
