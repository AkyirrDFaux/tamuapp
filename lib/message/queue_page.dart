import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../types.dart';
import 'message_queue.dart';
import 'compose_message_page.dart'; // Import the new file

class QueuePage extends StatefulWidget {
  const QueuePage({super.key});

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Scroll to the bottom when new messages are added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Queue'),
      ),
      body: Consumer<MessageQueue>(
        builder: (context, manager, child) {
          // Scroll to the bottom when new messages are added
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
          return ListView.builder(
            controller: _scrollController,
            itemCount: manager.entries.length,
            itemBuilder: (context, index) {
              final message = manager.entries[index];
              // Check if the message was sent or received
              return ChatBubble(
                message: message,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComposeMessagePage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final QueueEntry message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.direction == MessageDirection.output
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: message.message.getSegmentType(0) == Types.Status ? Colors.orange[300] :
          (message.direction == MessageDirection.output ? Colors.blue[100] : Colors.grey[300]),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Text(message.timestamp.hour.toString() + ":" +
            message.timestamp.minute.toString() + ":" +
            message.timestamp.second.toString() + " - " +
            message.message.toString()),
      ),
    );
  }
}