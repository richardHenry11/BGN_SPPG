import 'package:flutter/material.dart';
import 'services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> supplier;

  const ChatPage({super.key, required this.supplier});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final ChatService _chatService = ChatService.instance;
  List<_ChatMessage> _messages = [];

  late final String _supplierName;

  @override
  void initState() {
    super.initState();
    _supplierName = widget.supplier['name'] as String? ?? '';
    _chatService.addListener(_onChatChanged);
    _rebuildMessages();
  }

  @override
  void dispose() {
    _chatService.removeListener(_onChatChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    _rebuildMessages();
    _scrollToBottom();
  }

  void _rebuildMessages() {
    setState(() {
      _messages = _chatService.messages(_supplierName).map((m) => _ChatMessage(
        text: m.text,
        isMe: m.isFromSppg,
      )).toList();
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _chatService.sendMessage(text.trim(), 'SPPG', _supplierName);
    _controller.clear();
    _rebuildMessages();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.supplier['name'] as String? ?? '';
    final item = widget.supplier['item'] as String? ?? '';
    final imageUrl = widget.supplier['imageUrl'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 10, 30, 48),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 28, 46),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 40, 40, 40),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.store, color: Colors.grey),
                      )
                    : const Icon(Icons.store, color: Color(0xFF498CC8), size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (item.isNotEmpty)
                  Text(
                    item,
                    style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded,
                          size: 48, color: Color.fromARGB(255, 80, 80, 80),
                        ),
                        const SizedBox(height: 12),
                        const Text('Belum ada pesan',
                          style: TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text('Mulai percakapan dengan $name',
                          style: const TextStyle(color: Color.fromARGB(255, 90, 90, 90), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildBubble(msg);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 7, 28, 46),
              border: Border(top: BorderSide(color: Color.fromARGB(255, 30, 55, 75))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan...',
                      hintStyle: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 14),
                      filled: true,
                      fillColor: const Color.fromARGB(255, 20, 42, 62),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendMessage(_controller.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF135B92), Color(0xFF1A8FCC)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    final align = msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = msg.isMe
        ? const Color.fromARGB(255, 30, 70, 110)
        : const Color.fromARGB(255, 40, 40, 40);
    final margin = msg.isMe
        ? const EdgeInsets.only(left: 60, bottom: 8)
        : const EdgeInsets.only(right: 60, bottom: 8);

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: margin,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: msg.isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: msg.isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: align,
          children: [
            Text(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isMe;

  _ChatMessage({required this.text, required this.isMe});
}
