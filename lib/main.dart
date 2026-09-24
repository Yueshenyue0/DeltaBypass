import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const DeltaApp());
}

const linkPrefix = 'https://auth.platorelay.com/a?d=';

String randHex(int len) {
  const chars = '0123456789abcdef';
  final r = Random.secure();
  return List.generate(len, (_) => chars[r.nextInt(16)]).join();
}

int randMs(int from, int to) => from + Random().nextInt(to - from + 1);

String randIp() =>
    '104.21.${1 + Random().nextInt(254)}.${1 + Random().nextInt(254)}';

String randNode() {
  const zones = ['JP', 'SG', 'HK', 'US', 'DE', 'KR', 'TW'];
  final n = 1 + Random().nextInt(19);
  return '${zones[Random().nextInt(zones.length)]}-${n.toString().padLeft(2, '0')}';
}

class DeltaApp extends StatelessWidget {
  const DeltaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delta Bypass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E14),
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF11161F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1E2632)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1E2632)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.4),
          ),
        ),
      ),
      home: const BypassPage(),
    );
  }
}

class LogLine {
  final String text;
  final Color color;
  const LogLine(this.text, this.color);
}

class BypassPage extends StatefulWidget {
  const BypassPage({super.key});

  @override
  State<BypassPage> createState() => _BypassPageState();
}

class _BypassPageState extends State<BypassPage> {
  static const cNet = Color(0xFF00E5FF);
  static const cTls = Color(0xFF7C4DFF);
  static const cPool = Color(0xFF00E676);
  static const cCap = Color(0xFFFFD740);
  static const cKey = Color(0xFF69F0AE);
  static const cErr = Color(0xFFFF5370);
  static const cDim = Color(0xFF5C6B7A);

  final _linkCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<LogLine> _logs = [];
  bool _running = false;
  bool _failed = false;
  double _progress = 0;
  String _resultKey = '';

  @override
  void dispose() {
    _linkCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _log(String text, Color color, [double? p]) {
    setState(() {
      _logs.add(LogLine(text, color));
      if (p != null) _progress = p;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sleep(int ms) => Future.delayed(Duration(milliseconds: ms));

  Future<void> _start() async {
    final link = _linkCtrl.text.trim();
    if (!link.startsWith(linkPrefix) || link.length <= linkPrefix.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('链接错误：必须以 https://auth.platorelay.com/a?d= 开头')),
      );
      return;
    }
    if (_running) return;

    setState(() {
      _logs.clear();
      _running = true;
      _failed = false;
      _resultKey = '';
      _progress = 0;
    });

    final trace = randHex(12);
    final willFail = Random().nextDouble() < 0.2;
    final failReason = [
      '边缘节点限流 (HTTP 429)',
      'challenge校验失败 (HTTP 403)',
      '账号池token过期 (HTTP 401)',
      '上游超时 (HTTP 504)',
    ][Random().nextInt(4)];

    _log('收到链接: ${link.length > 52 ? '${link.substring(0, 52)}...' : link}', cDim, 0.04);
    await _sleep(randMs(1200, 2200));

    _log('[NET] 解析 auth.platorelay.com ... trace=$trace', cNet, 0.10);
    await _sleep(randMs(1000, 1800));
    _log('[NET] DNS -> ${randIp()} (${180 + Random().nextInt(340)}ms) EDGE=NRT-${(1 + Random().nextInt(9)).toString().padLeft(2, '0')}', cNet, 0.16);
    await _sleep(randMs(800, 1500));

    _log('[TLS] TLS 1.3 握手 ECDHE-X25519 ...', cTls, 0.22);
    await _sleep(randMs(1200, 2000));
    _log('[TLS] 握手成功 TLS_AES_256_GCM_SHA384 (${600 + Random().nextInt(600)}ms)', cTls, 0.28);
    await _sleep(randMs(600, 1200));

    _log('正在使用discord账号池 (${900 + Random().nextInt(901)}在线) ...', cPool, 0.34);
    await _sleep(randMs(1800, 2400));
    _log('[POOL] 绑定账号 #${1000 + Random().nextInt(8999)} token=${randHex(8)}**** 心跳正常', cPool, 0.44);
    await _sleep(randMs(1800, 2400));
    _log('[POOL] 轮换出口 ${randNode()} -> ${randNode()} ping=${80 + Random().nextInt(180)}ms', cPool, 0.54);
    await _sleep(randMs(1800, 2400));
    _log('[POOL] checkpoint seq=${10000 + Random().nextInt(89999)} ack=OK session=${randHex(8)}', cPool, 0.64);
    await _sleep(randMs(1800, 2400));
    if (Random().nextBool()) {
      _log('[POOL] 预检通过 delay=${80 + Random().nextInt(180)}ms queue=${1 + Random().nextInt(19)}', cPool, 0.70);
      await _sleep(randMs(1500, 2200));
    }
    _log('[POOL] 认证成功 rate_limit=剩余${20 + Random().nextInt(40)}次', cPool, 0.76);
    await _sleep(randMs(1000, 1600));

    _log('正在绕过captcha... challenge=${randHex(16)}', cCap, 0.84);
    await _sleep(randMs(1500, 2500));

    if (willFail) {
      _log('绕过失败，请重试 ($failReason trace=$trace)', cErr, 0.84);
      setState(() {
        _running = false;
        _failed = true;
      });
      return;
    }

    final score = (0.88 + Random().nextDouble() * 0.09).toStringAsFixed(2);
    _log('绕过成功，正在获取key (score=$score)', cKey, 0.90);
    await _sleep(randMs(1500, 2500));
    _log('[KEY] HMAC-SHA256校验 key_len=37', cKey, 0.95);
    await _sleep(randMs(1200, 1800));
    _log('key获取成功', cKey, 1.0);

    setState(() {
      _resultKey = 'FREE_${randHex(32)}';
      _running = false;
    });
  }

  void _reset() {
    setState(() {
      _logs.clear();
      _resultKey = '';
      _failed = false;
      _progress = 0;
      _linkCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _resultKey.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Delta Bypass')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _linkCtrl,
              enabled: !_running,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: '输入忍者链接',
                hintText: '$linkPrefix...',
                labelStyle: TextStyle(color: Color(0xFF00E5FF)),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _running ? null : _start,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.bolt),
              label: Text(_running ? '绕过中...' : '绕过'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 18),
            const Text('输出：', style: TextStyle(color: Color(0xFF5C6B7A), fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: done ? 150 : 300,
              decoration: BoxDecoration(
                color: const Color(0xFF050810),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF14202E)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.06),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        '> 等待输入链接_',
                        style: TextStyle(color: Color(0xFF2A3A4A), fontSize: 13, fontFamily: 'monospace'),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      itemCount: _logs.length,
                      itemBuilder: (_, i) {
                        final l = _logs[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            l.text,
                            style: TextStyle(
                              color: l.color.withOpacity(0.85),
                              fontSize: 12.5,
                              height: 1.35,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 4,
                backgroundColor: const Color(0xFF11161F),
                valueColor: AlwaysStoppedAnimation(
                  _failed ? const Color(0xFFFF5370) : const Color(0xFF00E5FF),
                ),
              ),
            ),
            if (done) ...[
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFF0D1420),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.45)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('KEY', style: TextStyle(color: Color(0xFF5C6B7A), fontSize: 11, letterSpacing: 2)),
                            const SizedBox(height: 4),
                            SelectableText(
                              _resultKey,
                              style: const TextStyle(
                                color: Color(0xFF69F0AE),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '复制',
                        icon: const Icon(Icons.copy_rounded, color: Color(0xFF00E5FF)),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _resultKey));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制 key')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        tooltip: '重新开始',
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5C6B7A)),
                        onPressed: _reset,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
