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
      // 标准 Material 3，跟随系统深浅色，控件全部用主题默认样式
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
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
  // 输出栏内的日志配色（仅终端框内部）
  static const cNet = Color(0xFF00ACC1);
  static const cTls = Color(0xFF7E57C2);
  static const cPool = Color(0xFF43A047);
  static const cCap = Color(0xFFFB8C00);
  static const cKey = Color(0xFF2E7D32);
  static const cErr = Color(0xFFE53935);
  static const cDim = Color(0xFF9E9E9E);

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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Delta Bypass')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标准 MD3 TextField
            TextField(
              controller: _linkCtrl,
              enabled: !_running,
              decoration: const InputDecoration(
                labelText: '输入忍者链接',
                hintText: '$linkPrefix...',
              ),
            ),
            const SizedBox(height: 16),
            // 标准 MD3 FilledButton（主题默认配色）
            FilledButton(
              onPressed: _running ? null : _start,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_running ? '绕过中...' : '绕过'),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '输出：',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 8),
            // 终端风格输出框（仅这里保留暗色）
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: done ? 150 : 300,
              decoration: BoxDecoration(
                color: const Color(0xFF101418),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2F36)),
              ),
              padding: const EdgeInsets.all(12),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        '> 等待输入链接_',
                        style: TextStyle(
                          color: Color(0xFF4A5560),
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
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
            // 标准 MD3 进度条（主题默认配色）
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 4,
                color: _failed ? scheme.error : null,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            if (done) ...[
              const SizedBox(height: 16),
              // 标准 MD3 Card
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 4, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('KEY', style: Theme.of(context).textTheme.labelSmall),
                            const SizedBox(height: 4),
                            SelectableText(
                              _resultKey,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      // 标准 MD3 IconButton
                      IconButton(
                        tooltip: '复制',
                        icon: const Icon(Icons.copy),
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
                        icon: const Icon(Icons.refresh),
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
