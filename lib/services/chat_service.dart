import 'package:flutter/foundation.dart';

class ChatMessage {
  final String text;
  final String sender;
  final DateTime timestamp;
  final String supplierName;

  ChatMessage({
    required this.text,
    required this.sender,
    required this.supplierName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isFromSppg => sender == 'SPPG';
}

class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._();
  static ChatService get instance => _instance;
  ChatService._();

  final Map<String, List<ChatMessage>> _conversations = {};

  List<String> get supplierNames => _conversations.keys.toList();

  List<ChatMessage> messages(String supplierName) {
    return _conversations[supplierName] ?? [];
  }

  ChatMessage? lastMessage(String supplierName) {
    final msgs = _conversations[supplierName];
    if (msgs == null || msgs.isEmpty) return null;
    return msgs.last;
  }

  void sendMessage(String text, String sender, String supplierName) {
    if (text.trim().isEmpty) return;
    _conversations.putIfAbsent(supplierName, () => []);
    _conversations[supplierName]!.add(ChatMessage(
      text: text.trim(),
      sender: sender,
      supplierName: supplierName,
    ));
    notifyListeners();
  }
}
