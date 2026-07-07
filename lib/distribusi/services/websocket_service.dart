import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  String? _wsUrl;
  int? _userId;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  static const int _maxReconnectAttempts = 5;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _channel != null;
  int? get userId => _userId;

  void connect(String url, int userId) {
    disconnect();
    _disposed = false;
    _wsUrl = url;
    _userId = userId;
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    _doConnect();
  }

  Future<void> _doConnect() async {
    if (_disposed) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl!));
      await _channel!.ready;
      _reconnectAttempts = 0;
      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            if (!_disposed) _messageController.add(msg);
          } catch (_) {}
        },
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
      );
      _sendRegister();
    } catch (_) {
      _onDisconnected();
    }
  }

  void _sendRegister() {
    if (_userId == null) return;
    send({'type': 'register', 'user_id': _userId, 'data': {}});
  }

  void send(Map<String, dynamic> message) {
    if (_channel == null || _disposed) return;
    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (_) {}
  }

  void sendLocation(int packagingId, double lat, double lng) {
    send({
      'type': 'location_update',
      'user_id': _userId,
      'data': {
        'packaging_id': packagingId,
        'latitude': lat,
        'longitude': lng,
      },
    });
  }

  void _onDisconnected() {
    _channel = null;
    if (!_shouldReconnect || _disposed) return;
    _reconnectAttempts++;
    if (_reconnectAttempts > _maxReconnectAttempts) {
      _shouldReconnect = false;
      return;
    }
    final delay = Duration(
      seconds: (_reconnectAttempts * 2).clamp(1, 30),
    );
    _reconnectTimer = Timer(delay, _doConnect);
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _messageController.close();
  }
}
