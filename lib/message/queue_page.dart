import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'message_queue.dart';
import '../object/object.dart';
import '../types.dart';
import '../functions.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Inspector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => MessageQueue().clear(),
          )
        ],
      ),
      body: Consumer<MessageQueue>(
        builder: (context, manager, child) {
          final entries = manager.entries;
          return ListView.builder(
            reverse: true, // Newest at bottom
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              // ListView is reversed, so index 0 is the last item in the list
              final entry = entries[entries.length - 1 - index];
              return ChatBubble(entry: entry);
            },
          );
        },
      ),
    );
  }
}

class ChatBubble extends StatefulWidget {
  final QueueEntry entry;
  const ChatBubble({super.key, required this.entry});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _showHex = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOutput = widget.entry.direction == MessageDirection.output;

    return Align(
      alignment: isOutput ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => setState(() => _showHex = !_showHex),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.92),
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isOutput ? "TX ↗ SEND" : "RX ↙ RECV",
                    style: TextStyle(
                      color: isOutput ? Colors.blueAccent : Colors.greenAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    _formatTime(widget.entry.timestamp),
                    style: const TextStyle(fontSize: 12, color: Colors.white30),
                  ),
                ],
              ),

              const Divider(height: 20, color: Colors.white10),

              // --- HEX VIEW ---
              if (_showHex && widget.entry.rawBytes != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _toHex(widget.entry.rawBytes!),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // --- SEGMENTED CONTENT (Updated for Depth) ---
              ...widget.entry.segments.map((segment) {
                final typeName = segment.type.toString().split('.').last;
                final isFunc = segment.type == Types.Function;

                // 12px indent per depth level
                final double leftPadding = (segment.depth * 12.0);

                return Padding(
                  padding: EdgeInsets.only(left: leftPadding, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sibling indicator for nested items
                      if (segment.depth > 0)
                        const Text("┕ ", style: TextStyle(color: Colors.white24, fontFamily: 'monospace')),

                      Text(
                        "$typeName: ",
                        style: TextStyle(
                          color: isFunc ? theme.colorScheme.primary : Colors.cyanAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatData(segment.data),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) =>
      "${t.hour}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}";

  String _toHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

  String _formatData(dynamic data) {
    if (data == null) return "null";
    if (data is Reference) {
      String loc = data.location.length > 0 ? ' Path: ${data.location}' : '';
      return "[${data.net}:${data.group}:${data.device}]$loc";
    }
    if (data is Enum) return data.name;
    if (data is Uint8List) return "Binary(${data.length}b)";
    return data.toString();
  }
}