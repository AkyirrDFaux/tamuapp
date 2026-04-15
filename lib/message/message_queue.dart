import 'dart:collection';
import 'package:flutter/material.dart';
import 'dart:typed_data';

enum MessageDirection { input, output }

class QueueSegment {
  final dynamic type; // e.g., Types.Status, Types.Reference
  final dynamic data; // The decoded value
  final int depth;    // UI Indentation level

  QueueSegment(this.type, this.data, {this.depth = 0});
}

class QueueEntry {
  final List<QueueSegment> segments;
  final DateTime timestamp;
  final MessageDirection direction;
  final Uint8List? rawBytes;

  QueueEntry({
    required this.segments,
    required this.timestamp,
    required this.direction,
    this.rawBytes,
  });
}

class MessageQueue extends ChangeNotifier {
  static final MessageQueue _instance = MessageQueue._internal();
  factory MessageQueue() => _instance;
  MessageQueue._internal({int maxLength = 500}) : _maxLength = maxLength;

  final int _maxLength;
  final Queue<QueueEntry> _queue = Queue<QueueEntry>();

  UnmodifiableListView<QueueEntry> get entries => UnmodifiableListView(_queue);

  void addSegments(List<QueueSegment> segments, MessageDirection direction, {Uint8List? raw}) {
    final entry = QueueEntry(
      segments: segments,
      timestamp: DateTime.now(),
      direction: direction,
      rawBytes: raw,
    );

    _queue.addLast(entry);
    if (_queue.length > _maxLength) _queue.removeFirst();
    notifyListeners();
  }

  void clear() {
    _queue.clear();
    notifyListeners();
  }
}