import 'message.dart'; // Assuming you have your Message class defined
import 'dart:collection';
import 'package:flutter/material.dart';

enum MessageDirection { input, output }

class QueueEntry {
  final Message message;
  final DateTime timestamp;
  final MessageDirection direction;

  QueueEntry({
    required this.message,
    required this.timestamp,
    required this.direction,
  });
}

class MessageQueue extends ChangeNotifier {
  // 1. Private Static Instance
  static final MessageQueue _instance = MessageQueue._internal();

  // 2. Factory Constructor
  factory MessageQueue() {
    return _instance;
  }

  // 3. Private Constructor
  MessageQueue._internal({int maxLength = 100}) : _maxLength = maxLength;

  final int _maxLength;
  final Queue<QueueEntry> _queue = Queue<QueueEntry>();

  UnmodifiableListView<QueueEntry> get entries => UnmodifiableListView(_queue);

  void addEntry(QueueEntry entry) {
    _queue.addLast(entry);
    if (_queue.length > _maxLength) {
      _queue.removeFirst();
    }
    notifyListeners();
  }
}