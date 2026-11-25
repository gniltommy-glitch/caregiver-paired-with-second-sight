import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'ws_transport.dart';

enum LinkMode { relayServer, directPiBridge }

class RelayLinkService {
  RelayLinkService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  void Function(Map<String, dynamic> message)? onMessage;
  void Function(bool connected)? onConnectionChanged;
  void Function(String error)? onError;

  CaregiverSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  Timer? _heartbeat;
  Timer? _retry;

  bool _wanted = false;
  bool connected = false;
  int _generation = 0;
  int _attempt = 0;
  DateTime _lastPong = DateTime.fromMillisecondsSinceEpoch(0);

  String endpoint = 'http://192.168.1.50:8787';
  String token = '';
  bool allowInsecure = true;
  LinkMode mode = LinkMode.relayServer;

  Uri buildUri(
    String path, {
    bool ws = false,
    Map<String, String>? queryParameters,
  }) {
    final base = Uri.tryParse(endpoint.trim());
    if (base == null ||
        !['http', 'https'].contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty) {
      throw const FormatException(
        'Địa chỉ máy chủ không hợp lệ (ví dụ: https://relay.ten-mien:8787 hoặc http://192.168.x.x:8787).',
      );
    }
    if (base.scheme == 'http' && !allowInsecure) {
      throw const FormatException(
        'Đang dùng HTTP chưa mã hóa. Hãy bật "Cho phép HTTP LAN thử nghiệm" hoặc chuyển sang HTTPS/WSS.',
      );
    }
    return base.replace(
      scheme: ws ? (base.scheme == 'https' ? 'wss' : 'ws') : base.scheme,
      path: path,
      queryParameters: (queryParameters == null || queryParameters.isEmpty)
          ? null
          : queryParameters,
      fragment: '',
    );
  }

  Future<void> connect() async {
    buildUri('/ws');
    if (token.trim().isEmpty) {
      throw const FormatException(
        'Vui lòng nhập Bearer token ghép đôi trước khi kết nối.',
      );
    }
    disconnect();
    _wanted = true;
    _attempt = 0;
    await _open(_generation);
  }

  Future<void> _open(int generation) async {
    if (!_wanted || generation != _generation) return;
    try {
      final wsUri = buildUri(
        '/ws',
        ws: true,
        queryParameters: mode == LinkMode.relayServer
            ? const <String, String>{'role': 'caregiver'}
            : null,
      );
      final channel = CaregiverSocket.connect(wsUri, token.trim());
      _socket = channel;
      await channel.ready.timeout(const Duration(seconds: 7));
      if (!_wanted || generation != _generation || _socket != channel) {
        await channel.close();
        return;
      }

      _lastPong = DateTime.now();
      _attempt = 0;

      _sub = channel.stream.listen(
        (dynamic raw) {
          if (generation != _generation) return;
          if (raw is! String || raw.length > 4 * 1024 * 1024) return;
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              if (decoded['type'] == 'pong') {
                _lastPong = DateTime.now();
              }
              onMessage?.call(decoded);
            }
          } catch (_) {
            // Bỏ qua gói JSON hỏng
          }
        },
        onDone: () {
          if (_socket == channel) _handleLost(generation);
        },
        onError: (Object e) {
          onError?.call(e.toString());
          if (_socket == channel) _handleLost(generation);
        },
        cancelOnError: false,
      );

      connected = true;
      onConnectionChanged?.call(true);

      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 4), (_) {
        if (DateTime.now().difference(_lastPong).inSeconds > 12) {
          _handleLost(generation);
          return;
        }
        sendWs(<String, dynamic>{
          'type': 'ping',
          'sent_at': DateTime.now().toUtc().toIso8601String(),
        });
      });
    } catch (e) {
      onError?.call('Không thể mở kết nối thời gian thực: $e');
      _handleLost(generation);
    }
  }

  void _handleLost(int generation) {
    if (generation != _generation || !_wanted) return;
    _heartbeat?.cancel();
    _sub?.cancel();
    _sub = null;
    _socket?.close();
    _socket = null;
    if (connected) {
      connected = false;
      onConnectionChanged?.call(false);
    }
    if (_retry?.isActive == true) return;
    final waitSeconds = min(30, 1 << min(_attempt++, 5));
    _retry = Timer(Duration(seconds: waitSeconds), () => _open(generation));
  }

  void sendWs(Map<String, dynamic> payload) {
    if (!connected) return;
    try {
      _socket?.send(jsonEncode(payload));
    } catch (_) {
      _handleLost(_generation);
    }
  }

  Map<String, String> get _headers => <String, String>{
    'Authorization': 'Bearer ${token.trim()}',
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> getJson(String path) async {
    final res = await _http
        .get(buildUri(path), headers: _headers)
        .timeout(const Duration(seconds: 7));
    if (res.statusCode != 200) {
      throw Exception('Máy chủ phản hồi mã ${res.statusCode} tại $path');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Phản hồi JSON không hợp lệ.');
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final res = await _http
        .post(buildUri(path), headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 7));
    if (res.statusCode != 200) {
      throw Exception(
        'Máy chủ từ chối yêu cầu (${res.statusCode}): ${res.body}',
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'ok': true};
  }

  void disconnect() {
    _wanted = false;
    _generation++;
    _retry?.cancel();
    _heartbeat?.cancel();
    _sub?.cancel();
    _sub = null;
    _socket?.close();
    _socket = null;
    final wasConnected = connected;
    connected = false;
    if (wasConnected) {
      onConnectionChanged?.call(false);
    }
  }

  void dispose() {
    disconnect();
    _http.close();
  }
}
