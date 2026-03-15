import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const LanClipboardSyncApp());
}

class LanClipboardSyncApp extends StatelessWidget {
  const LanClipboardSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LAN Clipboard Sync',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = ClipboardSyncService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _service.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('LAN Clipboard Sync'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dns), text: 'Host'),
              Tab(icon: Icon(Icons.link), text: 'Client'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            HostPanel(service: _service),
            ClientPanel(service: _service),
          ],
        ),
      ),
    );
  }
}

class HostPanel extends StatefulWidget {
  const HostPanel({super.key, required this.service});
  final ClipboardSyncService service;

  @override
  State<HostPanel> createState() => _HostPanelState();
}

class _HostPanelState extends State<HostPanel> {
  final _portController = TextEditingController(text: '8787');

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '监听端口'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () async {
                  final port = int.tryParse(_portController.text.trim()) ?? 8787;
                  await service.startHost(port);
                },
                child: const Text('启动 Host'),
              ),
              OutlinedButton(
                onPressed: service.stopHost,
                child: const Text('停止 Host'),
              ),
              OutlinedButton(
                onPressed: service.pushLocalClipboard,
                child: const Text('立即同步当前剪贴板'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('自动同步剪贴板'),
            value: service.autoSync,
            onChanged: service.setAutoSync,
          ),
          Text('Host 状态: ${service.hostStatus}'),
          Text('本机 IP: ${service.localIps.join(', ')}'),
          const SizedBox(height: 8),
          Text('日志:\n${service.logs.join('\n')}'),
        ],
      ),
    );
  }
}

class ClientPanel extends StatefulWidget {
  const ClientPanel({super.key, required this.service});
  final ClipboardSyncService service;

  @override
  State<ClientPanel> createState() => _ClientPanelState();
}

class _ClientPanelState extends State<ClientPanel> {
  final _hostController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '8787');

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(labelText: 'Host IP'),
          ),
          TextField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Host 端口'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () async {
                  final host = _hostController.text.trim();
                  final port = int.tryParse(_portController.text.trim()) ?? 8787;
                  await service.connectToHost(host, port);
                },
                child: const Text('连接 Host'),
              ),
              OutlinedButton(
                onPressed: service.disconnectClient,
                child: const Text('断开连接'),
              ),
              OutlinedButton(
                onPressed: service.pushLocalClipboard,
                child: const Text('立即同步当前剪贴板'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('自动同步剪贴板'),
            value: service.autoSync,
            onChanged: service.setAutoSync,
          ),
          Text('Client 状态: ${service.clientStatus}'),
          const SizedBox(height: 8),
          Text('日志:\n${service.logs.join('\n')}'),
        ],
      ),
    );
  }
}

class ClipboardSyncService extends ChangeNotifier {
  final List<String> logs = <String>[];
  String hostStatus = '未启动';
  String clientStatus = '未连接';
  bool autoSync = false;

  HttpServer? _httpServer;
  WebSocket? _clientSocket;
  final Set<WebSocket> _hostClients = <WebSocket>{};
  Timer? _pollTimer;
  String _lastClipboard = '';

  List<String> get localIps {
    final ips = <String>[];
    for (final ni in NetworkInterface.listSync()) {
      for (final addr in ni.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          ips.add(addr.address);
        }
      }
    }
    return ips;
  }

  Future<void> startHost(int port) async {
    await stopHost();
    try {
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      hostStatus = '运行中: 0.0.0.0:$port';
      _log('Host started on $port');
      _httpServer!.transform(WebSocketTransformer()).listen((socket) {
        _hostClients.add(socket);
        _log('Client connected (${_hostClients.length})');
        socket.listen(
          _handleIncoming,
          onDone: () {
            _hostClients.remove(socket);
            _log('Client disconnected (${_hostClients.length})');
          },
          onError: (e) => _log('Client socket error: $e'),
        );
      });
    } catch (e) {
      hostStatus = '启动失败: $e';
      _log('Host start failed: $e');
    }
    notifyListeners();
  }

  Future<void> stopHost() async {
    for (final ws in _hostClients) {
      await ws.close();
    }
    _hostClients.clear();
    await _httpServer?.close(force: true);
    _httpServer = null;
    hostStatus = '未启动';
    notifyListeners();
  }

  Future<void> connectToHost(String host, int port) async {
    await disconnectClient();
    try {
      _clientSocket = await WebSocket.connect('ws://$host:$port');
      clientStatus = '已连接: $host:$port';
      _log('Connected to host $host:$port');
      _clientSocket!.listen(
        _handleIncoming,
        onDone: () {
          clientStatus = '已断开';
          _log('Disconnected from host');
          notifyListeners();
        },
        onError: (e) {
          clientStatus = '连接错误: $e';
          _log('Client error: $e');
          notifyListeners();
        },
      );
    } catch (e) {
      clientStatus = '连接失败: $e';
      _log('Connect failed: $e');
    }
    notifyListeners();
  }

  Future<void> disconnectClient() async {
    await _clientSocket?.close();
    _clientSocket = null;
    clientStatus = '未连接';
    notifyListeners();
  }

  Future<void> pushLocalClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (text.isEmpty) {
      _log('Clipboard empty, skipped');
      notifyListeners();
      return;
    }
    _lastClipboard = text;
    final payload = jsonEncode({
      'type': 'clipboard_text',
      'text': text,
      'sender': '${Platform.operatingSystem}-${DateTime.now().millisecondsSinceEpoch}',
      'ts': DateTime.now().millisecondsSinceEpoch,
    });

    if (_clientSocket != null) {
      _clientSocket!.add(payload);
    }
    for (final ws in _hostClients) {
      ws.add(payload);
    }
    _log('Clipboard pushed (${text.length} chars)');
    notifyListeners();
  }

  void setAutoSync(bool enabled) {
    autoSync = enabled;
    _pollTimer?.cancel();
    if (enabled) {
      _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        final data = await Clipboard.getData('text/plain');
        final text = data?.text ?? '';
        if (text.isNotEmpty && text != _lastClipboard) {
          await pushLocalClipboard();
        }
      });
      _log('Auto sync enabled');
    } else {
      _log('Auto sync disabled');
    }
    notifyListeners();
  }

  Future<void> _handleIncoming(dynamic raw) async {
    try {
      final obj = jsonDecode(raw as String);
      if (obj is Map && obj['type'] == 'clipboard_text') {
        final text = (obj['text'] ?? '').toString();
        if (text.isNotEmpty && text != _lastClipboard) {
          _lastClipboard = text;
          await Clipboard.setData(ClipboardData(text: text));
          _log('Clipboard received (${text.length} chars)');
          notifyListeners();
        }
      }
    } catch (e) {
      _log('Incoming parse error: $e');
      notifyListeners();
    }
  }

  void _log(String msg) {
    logs.insert(0, '[${DateTime.now().toIso8601String()}] $msg');
    if (logs.length > 60) {
      logs.removeLast();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    stopHost();
    disconnectClient();
    super.dispose();
  }
}
