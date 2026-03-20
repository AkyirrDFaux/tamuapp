import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../object/object.dart';
import '../types.dart';
import '../functions.dart';
import 'message_queue.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor and AppBar style are now automatic!
      appBar: AppBar(
        title: const Text('Message Inspector'),
      ),
      body: Consumer<MessageQueue>(
        builder: (context, manager, child) {
          final entries = manager.entries;
          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final messageEntry = entries[entries.length - 1 - index];
              return ChatBubble(message: messageEntry);
            },
          );
        },
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final QueueEntry message;
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOutput = message.direction == MessageDirection.output;
    final valueEntries = message.message.valueEntries;

    return Align(
      alignment: isOutput ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.92), // Slightly wider
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.all(14.0), // More padding for larger text
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER (TX/RX and Time) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOutput ? "TX ↗" : "RX ↙",
                  style: TextStyle(
                    color: isOutput ? Colors.white60 : theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12, // Increased from 10
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}:${message.timestamp.second.toString().padLeft(2, '0')}",
                  style: const TextStyle(fontSize: 12, color: Colors.white30),
                ),
              ],
            ),

            const Divider(height: 20), // Increased spacing around divider

            // --- HIERARCHICAL CONTENT ---
            ...valueEntries.map((entry) {
              final double indent = entry.path.indices.length * 18.0; // Increased indent for readability
              final String typeName = entry.type.toString().split('.').last;

              return Padding(
                padding: const EdgeInsets.only(left: 0, bottom: 6), // Added bottom spacing between lines
                child: Padding(
                  padding: EdgeInsets.only(left: indent),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.path.indices.isNotEmpty)
                        const Text("• ", style: TextStyle(color: Colors.white24, fontSize: 16)),

                      Text(
                        "$typeName: ",
                        style: TextStyle(
                          color: entry.type == Types.Function ? theme.colorScheme.primary : Colors.cyanAccent,
                          fontSize: 15, // Increased from 12
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatData(entry.data),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15, // Increased from 12
                            fontFamily: 'monospace',
                            height: 1.3, // Added line height for multi-line text
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  String _formatData(dynamic data) {
    if (data == null) return "null";
    if (data is Reference) return data.fullAddress;
    if (data is Functions || data is ObjectTypes) return data.toString().split('.').last;
    return data.toString();
  }
}