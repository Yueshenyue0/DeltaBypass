package com.eri.deltabypass.ui.screen

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.theme.MiuixTheme
import kotlin.random.Random

private const val LINK_PREFIX = "https://auth.platorelay.com/a?d="

private fun randomHexKey(): String {
    val hex = "0123456789abcdef"
    val sb = StringBuilder("FREE_")
    repeat(32) { sb.append(hex[Random.nextInt(hex.length)]) }
    return sb.toString()
}

@Composable
fun BypassScreen() {
    var link by rememberSaveable { mutableStateOf("") }
    var linkError by rememberSaveable { mutableStateOf(false) }
    var running by remember { mutableStateOf(false) }
    var resultKey by rememberSaveable { mutableStateOf("") }
    var failed by remember { mutableStateOf(false) }
    var copied by remember { mutableStateOf(false) }
    val logLines = remember { mutableStateListOf<String>() }
    val scope = rememberCoroutineScope()
    val clipboard = LocalClipboardManager.current
    val logScroll = rememberScrollState()
    val pageScroll = rememberScrollState()

    // 完成后输出框缩小
    val logHeight by animateDpAsState(
        targetValue = if (resultKey.isNotEmpty()) 132.dp else 240.dp,
        label = "logHeight"
    )

    // 日志自动滚到底部
    LaunchedEffect(logLines.size) {
        logScroll.animateScrollTo(logScroll.maxValue)
    }

    // 复制成功提示自动消失
    LaunchedEffect(copied) {
        if (copied) {
            delay(1500)
            copied = false
        }
    }

    fun startBypass() {
        val trimmed = link.trim()
        if (!trimmed.startsWith(LINK_PREFIX) || trimmed.length <= LINK_PREFIX.length) {
            linkError = true
            return
        }
        linkError = false
        resultKey = ""
        failed = false
        copied = false
        logLines.clear()
        running = true
        scope.launch {
            logLines += "收到链接"
            delay(Random.nextLong(1500, 2501))

            logLines += "正在绕过captcha..."
            delay(Random.nextLong(12_000, 20_001))

            // 概率失败
            if (Random.nextDouble() < 0.15) {
                logLines += "绕过失败，请重试"
                failed = true
                running = false
                return@launch
            }

            logLines += "绕过成功，正在获取key"
            delay(Random.nextLong(1500, 2501))

            logLines += "key获取成功"
            resultKey = randomHexKey()
            running = false
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(pageScroll)
            .padding(horizontal = 20.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(24.dp))

        TextField(
            value = link,
            onValueChange = {
                link = it
                if (linkError) linkError = false
            },
            label = "输入忍者链接",
            useLabelAsPlaceholder = true,
            singleLine = true,
            enabled = !running
        )

        if (linkError) {
            Text(
                text = "链接错误",
                color = Color(0xFFD32F2F),
                style = MiuixTheme.textStyles.body2,
                modifier = Modifier
                    .align(Alignment.Start)
                    .padding(start = 16.dp, top = 6.dp)
            )
        }

        Spacer(modifier = Modifier.height(20.dp))

        Button(
            onClick = { startBypass() },
            enabled = !running,
            colors = ButtonDefaults.buttonColorsPrimary(),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(if (running) "绕过中..." else "绕过")
        }

        Spacer(modifier = Modifier.height(20.dp))

        // 输出框（完成后高度动画缩小）
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .height(logHeight)
        ) {
            if (logLines.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "等待输入链接",
                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                        style = MiuixTheme.textStyles.body2
                    )
                }
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(logScroll)
                        .padding(16.dp)
                ) {
                    logLines.forEachIndexed { index, line ->
                        val isErrorLine = failed && index == logLines.lastIndex
                        Text(
                            text = line,
                            color = if (isErrorLine) Color(0xFFD32F2F)
                            else MiuixTheme.colorScheme.onSurface,
                            style = MiuixTheme.textStyles.body2,
                            modifier = Modifier.padding(vertical = 3.dp)
                        )
                    }
                }
            }
        }

        // 成功后生成 key 卡片
        AnimatedVisibility(visible = resultKey.isNotEmpty()) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Key",
                            style = MiuixTheme.textStyles.title2,
                            color = MiuixTheme.colorScheme.onSurface
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = resultKey,
                            style = MiuixTheme.textStyles.main,
                            fontFamily = FontFamily.Monospace,
                            color = MiuixTheme.colorScheme.primary
                        )
                    }
                    TextButton(
                        text = if (copied) "已复制" else "复制",
                        onClick = {
                            clipboard.setText(AnnotatedString(resultKey))
                            copied = true
                        },
                        colors = ButtonDefaults.textButtonColorsPrimary()
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))
    }
}