import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'chat_page.dart';
import 'distribusi/providers/auth_provider.dart';
import 'services/chat_service.dart';

class ChatInboxPage extends StatefulWidget {
  const ChatInboxPage({super.key});

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage> {
  final ChatService _chatService = ChatService.instance;
  List<Map<String, dynamic>> _suppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _chatService.addListener(_onChatChanged);
    _fetchSuppliers();
  }

  @override
  void dispose() {
    _chatService.removeListener(_onChatChanged);
    super.dispose();
  }

  void _onChatChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchSuppliers() async {
    try {
      final auth = context.read<AuthProvider>();
      final res = await http.get(
        Uri.parse('https://sppg.cbinstrument.com/api/procurement/supplier-products'),
        headers: {
          'Accept': 'application/json',
          'x-user-Sppg-id': auth.sppgId ?? '',
          'x-user-Role': auth.currentRole,
        },
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body) as List<dynamic>;
        final seen = <String>{};
        final suppliers = <Map<String, dynamic>>[];
        for (final e in data) {
          final api = e as Map<String, dynamic>;
          final name = api['supplier_name'] as String? ?? '';
          if (name.isEmpty || seen.contains(name)) continue;
          seen.add(name);
          suppliers.add({
            'name': name,
            'item': api['name'] ?? '',
            'imageUrl': api['image_url'] ?? '',
            'distance': '${api['supplier_distance'] ?? 0} km',
            'rating': (api['supplier_rating'] ?? 0).toDouble(),
          });
        }
        setState(() { _suppliers = suppliers; _loading = false; });
      } else {
        setState(() { _loading = false; });
      }
    } catch (_) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatted = _chatService.supplierNames;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 10, 30, 48),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 28, 46),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Chat Supplier',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1A8FCC)))
          : _suppliers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded,
                        size: 48, color: Color.fromARGB(255, 80, 80, 80),
                      ),
                      const SizedBox(height: 12),
                      const Text('Chat kosong',
                        style: TextStyle(color: Color.fromARGB(255, 140, 140, 140), fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      const Text('Belum ada percakapan dengan Supplier',
                        style: TextStyle(color: Color.fromARGB(255, 90, 90, 90), fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _suppliers.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: Color.fromARGB(255, 40, 40, 40),
                    height: 1,
                    indent: 72,
                  ),
                  itemBuilder: (_, i) {
                    final s = _suppliers[i];
                    final name = s['name'] as String;
                    final lastMsg = _chatService.lastMessage(name);
                    final hasChat = chatted.contains(name);

                    return _buildSupplierTile(s, name, hasChat, lastMsg);
                  },
                ),
    );
  }

  Widget _buildSupplierTile(Map<String, dynamic> s, String name, bool hasChat, ChatMessage? lastMsg) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatPage(supplier: s)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 40, 40, 40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (s['imageUrl'] as String).isNotEmpty
                      ? Image.network(
                          s['imageUrl'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.store, color: Colors.grey, size: 24),
                        )
                      : const Icon(Icons.store, color: Color(0xFF498CC8), size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (hasChat && lastMsg != null)
                      Text(lastMsg.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color.fromARGB(255, 133, 133, 133), fontSize: 12),
                      )
                    else
                      Text(s['item'] as String,
                        style: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (s['distance'] != null)
                Text(s['distance'] as String,
                  style: const TextStyle(color: Color.fromARGB(255, 100, 100, 100), fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
