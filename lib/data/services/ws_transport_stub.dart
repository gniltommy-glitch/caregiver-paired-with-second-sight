import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_transport.dart';

CaregiverSocket connectCaregiverSocket(Uri uri, String _) =>
    _WebCaregiverSocket(uri);

class _WebCaregiverSocket implements CaregiverSocket {
  late final WebSocketChannel _channel;

  _WebCaregiverSocket(Uri uri) {
    _channel = WebSocketChannel.connect(uri);
  }

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  Future<void> get ready => _channel.ready;

  @override
  void send(String data) => _channel.sink.add(data);

  @override
  Future<void> close() => _channel.sink.close();
}
