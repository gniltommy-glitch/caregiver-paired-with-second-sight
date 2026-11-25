import 'ws_transport_stub.dart'
    if (dart.library.io) 'ws_transport_io.dart'
    as impl;

abstract class CaregiverSocket {
  Stream<dynamic> get stream;
  Future<void> get ready;
  void send(String data);
  Future<void> close();

  static CaregiverSocket connect(Uri uri, String token) =>
      impl.connectCaregiverSocket(uri, token);
}
