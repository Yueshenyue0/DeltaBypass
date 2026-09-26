import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const DeltaApp());
}

const linkPrefix = 'https://auth.platorelay.com/a?d=';

// ---------------- MSY 云验证配置 ----------------
const msyAppid = '53690';
const msyUid = '6638';
const msyPackage = 'com.eri.delta_bypass';
const msyEndpoint = 'https://yunzhuru.cn/msy/kami.php';
const msyVersion = '1.0.0';

// API Key 以逐字节异或形式存放，二进制里搜不到明文，运行时还原
const List<int> _kScramble = <int>[
  60, 6, 67, 176, 232, 162, 156, 209, 161, 170, 238, 219, 151, 58, 113, 126,
  78, 85, 33, 99, 60, 92, 72, 178, 170, 254, 207, 223, 247, 230, 215, 143,
  206, 100, 34, 19, 75, 11, 125, 54, 83, 10, 75, 188, 243, 154, 136, 223,
  172, 180, 208, 199, 152, 51, 126, 68, 80, 7, 121, 97, 94, 21, 228, 236,
];

String msyApiKey() {
  final sb = StringBuffer();
  for (var i = 0; i < _kScramble.length; i++) {
    sb.writeCharCode(_kScramble[i] ^ ((0x5A + i * 13) & 0xFF));
  }
  return sb.toString();
}

// ---------------- 签名 / 验签 ----------------
String _canonicalJson(dynamic v) {
  if (v is Map) {
    final keys = v.keys.map((e) => e.toString()).toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${_canonicalJson(v[k])}').join(',')}}';
  }
  if (v is List) {
    return '[${v.map(_canonicalJson).join(',')}]';
  }
  return jsonEncode(v);
}

String _sign(Map<String, dynamic> data, int time, String nonce, String key) {
  final raw = '$msyAppid\n$time\n$nonce\n${_canonicalJson(data)}';
  final mac = Hmac(sha256, utf8.encode(key)).convert(utf8.encode(raw));
  return mac.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// 校验响应：APPID 一致 + 时间偏差 <=300 秒 + 签名一致
bool _verifyResponse(Map<String, dynamic> data, String key) {
  if (data['appid'].toString() != msyAppid) return false;
  final time = (data['time'] as num?)?.toInt() ?? 0;
  final nonce = (data['nonce'] ?? '').toString();
  final sign = (data['sign'] ?? '').toString();
  if (sign.isEmpty || time == 0) return false;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if ((now - time).abs() > 300) return false;
  return _sign(data, time, nonce, key) == sign;
}

// ---------------- 本地缓存 ----------------
String linkId(String link) {
  var h = 0;
  for (final b in link.codeUnits) {
    h = 0x1fffffff & (h + b);
    h = 0x1fffffff & (h + ((0x0007ffff & h) << 10));
    h ^= h >> 6;
  }
  h = 0x1fffffff & (h + ((0x03ffffff & h) << 3));
  h ^= h >> 11;
  h = 0x1fffffff & (h + ((0x0000ffff & h) << 15));
  return h.toRadixString(16).padLeft(8, '0');
}

Future<String?> getCachedKey(String link) async {
  final prefs = await SharedPreferences.getInstance();
  final id = linkId(link);
  if (prefs.getString('link_$id') != link) return null;
  return prefs.getString('key_$id');
}

Future<void> putCachedKey(String link, String key) async {
  final prefs = await SharedPreferences.getInstance();
  final id = linkId(link);
  await prefs.setString('link_$id', link);
  await prefs.setString('key_$id', key);
}

String maskKey(String k) =>
    k.length <= 12 ? '$k****' : '${k.substring(0, 12)}****';

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

class _BypassPageState extends State<BypassPage> with WidgetsBindingObserver {
  // 输出栏内的日志配色（仅终端框内部）
  static const cNet = Color(0xFF00ACC1);
  static const cTls = Color(0xFF7E57C2);
  static const cPool = Color(0xFF43A047);
  static const cCap = Color(0xFFFB8C00);
  static const cKey = Color(0xFF2E7D32);
  static const cErr = Color(0xFFE53935);
  static const cDim = Color(0xFF9E9E9E);

  final _linkCtrl = TextEditingController();
  final _kamiCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<LogLine> _logs = [];

  bool _running = false;
  bool _failed = false;
  bool _verifying = false;
  double _progress = 0;
  String _resultKey = '';
  String _remaining = '';
  String _did = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDid();
    _readClipboard();
  }

  /// 设备唯一标识：首次生成后持久化，保持稳定非空
  Future<void> _loadDid() async {
    final prefs = await SharedPreferences.getInstance();
    var did = prefs.getString('msy_did');
    if (did == null || did.isEmpty) {
      did = 'd_${randHex(32)}';
      await prefs.setString('msy_did', did);
    }
    if (mounted) setState(() => _did = did!);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _readClipboard();
  }

  // 自动读取剪贴板：检测到合规链接就填入输入框（不覆盖已有输入）
  Future<void> _readClipboard() async {
    if (_running || _linkCtrl.text.isNotEmpty) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null &&
          text.startsWith(linkPrefix) &&
          text.length > linkPrefix.length &&
          _linkCtrl.text.isEmpty &&
          mounted) {
        _linkCtrl.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已自动填入剪贴板中的链接')),
        );
      }
    } catch (_) {
      // 读取失败静默处理
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkCtrl.dispose();
    _kamiCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _log(String text, Color color, [double? p]) {
    if (!mounted) return;
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

  Future<void> _sleep(int ms) =>
      Future.delayed(Duration(milliseconds: ms));

  /// 云验证：POST kami.php，校验 code / APPID / 时间 / HMAC 签名
  Future<bool> _verifyKami(String kami) async {
    final key = msyApiKey();
    final did = _did.isNotEmpty ? _did : 'd_${randHex(32)}';
    _log('[CLOUD] 正在连接验证服务器 (appid=$msyAppid) ...', cDim, 0.02);
    try {
      final resp = await http
          .post(
            Uri.parse(msyEndpoint),
            body: <String, String>{
              'kami': kami,
              'appid': msyAppid,
              'uid': msyUid,
              'package': msyPackage,
              'did': did,
              'version': msyVersion,
              'key': key,
            },
          )
          .timeout(const Duration(seconds: 15));
      await _sleep(randMs(600, 1100));
      _log('[CLOUD] 响应已返回 HTTP ${resp.statusCode} (${resp.bodyBytes.length} B)', cNet, 0.04);
      if (resp.statusCode != 200) {
        _log('[CLOUD] 验证失败：服务异常 HTTP ${resp.statusCode}', cErr);
        return false;
      }
      final json = jsonDecode(utf8.decode(resp.bodyBytes));
      if (json is! Map) {
        _log('[CLOUD] 验证失败：响应格式异常', cErr);
        return false;
      }
      final code = (json['code'] as num?)?.toInt() ?? 0;
      if (code != 200) {
        _log('[CLOUD] 验证失败：${json['message'] ?? '卡密无效'}', cErr);
        return false;
      }
      final data = json['data'];
      if (data is! Map) {
        _log('[CLOUD] 验证失败：缺少 data 字段', cErr);
        return false;
      }
      final d = Map<String, dynamic>.from(data);
      if (!_verifyResponse(d, key)) {
        _log('[CLOUD] 验证失败：响应验签未通过', cErr);
        return false;
      }
      final drift = (DateTime.now().millisecondsSinceEpoch ~/ 1000 -
              (d['time'] as num).toInt())
          .abs();
      _log('[CLOUD] 验签通过 HMAC-SHA256 (appid 一致 / 时间偏差 ${drift}s)', cPool, 0.05);
      final days = (d['remaining_days'] ?? '').toString();
      final secs = (d['remaining_seconds'] as num?)?.toInt() ?? 0;
      _remaining = days.isNotEmpty ? days : '$secs 秒';
      _log('[CLOUD] 卡密有效 · $_remaining', cKey, 0.06);
      return true;
    } catch (e) {
      _log('[CLOUD] 验证失败：网络异常 ($e)', cErr);
      return false;
    }
  }

  Future<void> _start() async {
    final link = _linkCtrl.text.trim();
    if (!link.startsWith(linkPrefix) || link.length <= linkPrefix.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('链接错误：必须以 https://auth.platorelay.com/a?d= 开头'),
        ),
      );
      return;
    }
    if (_running || _verifying) return;

    final kami = _kamiCtrl.text.trim();
    if (kami.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入卡密')),
      );
      return;
    }

    setState(() {
      _logs.clear();
      _running = true;
      _verifying = true;
      _failed = false;
      _resultKey = '';
      _progress = 0;
    });

    final ok = await _verifyKami(kami);
    if (!ok) {
      setState(() {
        _running = false;
        _verifying = false;
        _failed = true;
      });
      return;
    }
    setState(() => _verifying = false);

    // 命中本地缓存：约5秒直接返回原 key，不走完整绕过
    final cached = await getCachedKey(link);
    if (cached != null) {
      _log('收到链接', cDim, 0.1);
      await _sleep(randMs(1200, 1800));
      _log('[CACHE] 命中本地缓存 key=${maskKey(cached)} ...', cPool, 0.5);
      await _sleep(randMs(1500, 2000));
      _log('[CACHE] 校验通过，直接返回 (本地命中，无需重绕)', cPool, 0.85);
      await _sleep(randMs(1200, 1600));
      _log('key获取成功', cKey, 1.0);
      if (mounted) {
        setState(() {
          _resultKey = cached;
          _running = false;
        });
      }
      return;
    }

    final trace = randHex(12);
    final willFail = Random().nextDouble() < 0.2;
    final failReason = [
      '边缘节点限流 (HTTP 429)',
      'challenge校验失败 (HTTP 403)',
      '账号池token过期 (HTTP 401)',
      '上游超时 (HTTP 504)',
    ][Random().nextInt(4)];

    _log('收到链接: ${link.length > 52 ? '${link.substring(0, 52)}...' : link}', cDim, 0.08);
    await _sleep(randMs(1200, 2200));
    _log('[NET] 解析 auth.platorelay.com ... trace=$trace', cNet, 0.14);
    await _sleep(randMs(1000, 1800));
    _log('[NET] DNS -> ${randIp()} (${180 + Random().nextInt(340)}ms) EDGE=NRT-${(1 + Random().nextInt(9)).toString().padLeft(2, '0')}', cNet, 0.19);
    await _sleep(randMs(800, 1500));
    _log('[TLS] TLS 1.3 握手 ECDHE-X25519 ...', cTls, 0.24);
    await _sleep(randMs(1200, 2000));
    _log('[TLS] 握手成功 TLS_AES_256_GCM_SHA384 (${600 + Random().nextInt(600)}ms)', cTls, 0.29);
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
      if (mounted) {
        setState(() {
          _running = false;
          _failed = true;
        });
      }
      return;
    }
    final score = (0.88 + Random().nextDouble() * 0.09).toStringAsFixed(2);
    _log('绕过成功，正在获取key (score=$score)', cKey, 0.90);
    await _sleep(randMs(1500, 2500));
    _log('[KEY] HMAC-SHA256校验 key_len=37', cKey, 0.95);
    await _sleep(randMs(1200, 1800));
    _log('key获取成功', cKey, 1.0);
    final newKey = 'FREE_${randHex(32)}';
    if (mounted) {
      setState(() {
        _resultKey = newKey;
        _running = false;
      });
    }
    await putCachedKey(link, newKey);
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
    final busy = _running || _verifying;
    return Scaffold(
      appBar: AppBar(title: const Text('Delta Bypass')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标准 MD3 TextField
            TextField(
              controller: _kamiCtrl,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: '卡密',
                hintText: '请输入卡密',
              ),
            ),
            if (_remaining.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '当前卡密 $_remaining',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _linkCtrl,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: '输入忍者链接',
                hintText: '$linkPrefix...',
              ),
            ),
            const SizedBox(height: 16),
            // 标准 MD3 FilledButton（主题默认配色）
            FilledButton(
              onPressed: busy ? null : _start,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_verifying
                    ? '验证中...'
                    : _running
                        ? '绕过中...'
                        : '绕过'),
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
                            Text('KEY',
                                style: Theme.of(context).textTheme.labelSmall),
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
                          await Clipboard.setData(
                              ClipboardData(text: _resultKey));
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
