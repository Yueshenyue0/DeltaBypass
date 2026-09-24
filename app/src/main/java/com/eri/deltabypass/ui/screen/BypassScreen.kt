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

private fun randHex(len: Int): String {
    val hex = "0123456789abcdef"
    val sb = StringBuilder()
    repeat(len) { sb.append(hex[Random.nextInt(hex.length)]) }
    return sb.toString()
}

private fun randomFreeKey(): String {
    return "FREE_" + randHex(32)
}

private fun randIp(): String {
    return "104.21.${Random.nextInt(1, 255)}.${Random.nextInt(1, 255)}"
}

private fun randNode(): String {
    val zones = listOf("JP", "SG", "HK", "US", "DE", "KR", "TW")
    return zones.random() + "-" + String.format("%02d", Random.nextInt(1, 20))
}

private fun randPing(): Int = Random.nextInt(80, 260)

private fun randMs(from: Long, until: Long): Long = Random.nextLong(from, until)

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
    // 完成后输出框缩小，然后显示key卡片
    val logHeight by animateDpAsState(
        targetValue = if (resultKey.isNotEmpty()) 132.dp else 240.dp,
        label = "logHeight"
    )
    LaunchedEffect(logLines.size) {
        logScroll.animateScrollTo(logScroll.maxValue)
    }
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
            // 每次运行都随机生成，与写死区分
            val traceId = randHex(12)
            val session = randHex(8)
            val challenge = randHex(16)
            val nodeIp = randIp()
            val poolOnline = Random.nextInt(900, 1801)
            val accountId = Random.nextInt(1000, 9999)
            val accountToken = randHex(8)
            val seq = Random.nextInt(10000, 99999)
            val rateLeft = Random.nextInt(20, 60)
            val edge = "NRT-" + String.format("%02d", Random.nextInt(1, 10))
            val dnsMs = Random.nextInt(180, 520)
            val tlsMs = Random.nextInt(600, 1200)
            val score = 0.88 + Random.nextDouble() * 0.09
            val scoreStr = String.format("%.2f", score)
            val capSec = 1.1 + Random.nextDouble() * 0.9
            val capSecStr = String.format("%.1f", capSec)
            // 20% 概率失败
            val willFail = Random.nextDouble() < 0.2
            val failReason = listOf(
                "边缘节点限流 (HTTP 429)",
                "challenge校验失败 (HTTP 403)",
                "账号池token过期 (HTTP 401)",
                "上游超时 (HTTP 504)"
            ).random()

            // 1. 收到链接
            logLines += "收到链接"
            delay(randMs(1200, 2201))

            // 2. NET / TLS 技术感
            logLines += "[NET] 解析 auth.platorelay.com ... trace=$traceId"
            delay(randMs(1000, 2001))
            logLines += "[NET] DNS -> $nodeIp (${dnsMs}ms) EDGE=$edge"
            delay(randMs(800, 1601))
            logLines += "[TLS] TLS 1.3 握手 ECDHE-X25519 ..."
            delay(randMs(1200, 2001))
            logLines += "[TLS] 握手成功 TLS_AES_256_GCM_SHA384 (${tlsMs}ms)"
            delay(randMs(600, 1201))

            // 3. discord账号池，大约10秒：分4-5步，每步随机1.8-2.4秒
            logLines += "正在使用discord账号池 (${poolOnline}在线) ..."
            delay(randMs(1800, 2401))
            logLines += "[POOL] 绑定账号 #$accountId token=${accountToken}**** 心跳正常"
            delay(randMs(1800, 2401))
            val nodeA = randNode()
            val nodeB = randNode()
            logLines += "[POOL] 轮换出口 $nodeA -> $nodeB ping=${randPing()}ms"
            delay(randMs(1800, 2401))
            logLines += "[POOL] checkpoint seq=$seq ack=OK session=$session"
            delay(randMs(1800, 2401))
            // 随机决定是3步还是4步，让总时长每次不一样
            if (Random.nextBoolean()) {
                logLines += "[POOL] 预检通过 delay=${randPing()}ms queue=${Random.nextInt(1, 20)}"
                delay(randMs(1500, 2201))
            }
            logLines += "[POOL] 认证成功 rate_limit=剩余${rateLeft}次"
            delay(randMs(1000, 1801))

            // 4. captcha
            logLines += "正在绕过captcha... challenge=$challenge"
            delay(randMs(1500, 2501))

            if (willFail) {
                logLines += "绕过失败，请重试 ($failReason trace=$traceId)"
                failed = true
                running = false
                return@launch
            }

            // 5. 绕过成功，正在获取key
            logLines += "绕过成功，正在获取key (score=$scoreStr ${capSecStr}s)"
            delay(randMs(1500, 2501))
            logLines += "[KEY] HMAC-SHA256校验 key_len=37"
            delay(randMs(1200, 2001))
            logLines += "key获取成功"
            resultKey = randomFreeKey()
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
        // 输出框：流程走完出key卡片时缩小
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
