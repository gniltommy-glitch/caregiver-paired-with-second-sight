import 'dart:async';
import 'dart:io';

import 'ws_transport.dart';

CaregiverSocket connectCaregiverSocket(Uri uri, String token) =>
    _IoCaregiverSocket(uri, token);

class _IoCaregiverSocket implements CaregiverSocket {
  final _controller = StreamController<dynamic>();
  final _readyCompleter = Completer<void>();
  WebSocket? _ws;

  _IoCaregiverSocket(Uri uri, String token) {
    WebSocket.connect(
          uri.toString(),
          headers: <String, dynamic>{'Authorization': 'Bearer $token'},
        )
        .then((ws) {
          ws.pingInterval = const Duration(seconds: 12);
          _ws = ws;
          if (!_readyCompleter.isCompleted) {
            _readyCompleter.complete();
          }
          ws.listen(
            _controller.add,
            onError: _controller.addError,
            onDone: _controller.close,
            cancelOnError: false,
          );
        })
        .catchError((Object err, StackTrace st) {
          if (!_readyCompleter.isCompleted) {
            _readyCompleter.completeError(err, st);
          }
          if (!_controller.isClosed) {
            _controller.close();
          }
        });
  }

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  void send(String data) {
    _ws?.add(data);
  }

  @override
  Future<void> close() async {
    await _ws?.close();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
