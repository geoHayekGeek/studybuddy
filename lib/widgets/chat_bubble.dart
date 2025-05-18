// lib/widgets/chat_bubble.dart
import 'package:flutter/material.dart';
import '../../models/chat_model.dart';
import 'formatted_text.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;

  const ChatBubble({super.key, required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: FormattedText(
          content: message.content,
          defaultStyle: TextStyle(
            color: isUser ? Colors.white : Colors.black,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}