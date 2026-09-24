package com.eri.deltabypass.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import top.yukonga.miuix.kmp.theme.*

@Composable
fun DeltaBypassTheme(content: @Composable () -> Unit) {
    // System 模式：自动跟随系统深色/浅色
    val controller = remember { ThemeController(ColorSchemeMode.System) }
    MiuixTheme(controller = controller, content = content)
}