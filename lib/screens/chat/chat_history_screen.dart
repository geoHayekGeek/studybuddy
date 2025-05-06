// lib/screens/chat/chat_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';

class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatMessages = ref.watch(chatMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
      ),
      body: chatMessages.isEmpty
          ? const Center(child: Text('No chat history available.'))
          : ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: chatMessages.length,
        itemBuilder: (context, index) {
          final message = chatMessages[index];
          return ListTile(
            title: Text(
              message.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              message.timestamp.toLocal().toString(),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            leading: Icon(
              message.sender == 'user' ? Icons.person : Icons.smart_toy,
              color: message.sender == 'user' ? Colors.blue : Colors.green,
            ),
            onTap: () {
              // Navigate back to chat screen with selected conversation (if needed)
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}