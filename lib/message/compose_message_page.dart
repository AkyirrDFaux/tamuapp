import 'package:flutter/material.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../editables/editable_field.dart';
import '../types.dart';
import 'message.dart'; // Import your message.dart

class ComposeMessagePage extends StatefulWidget {
  const ComposeMessagePage({super.key});

  @override
  State<ComposeMessagePage> createState() => _ComposeMessagePageState();
}

class _ComposeMessagePageState extends State<ComposeMessagePage> {
  Message message = Message();

  @override
  void dispose() {
    super.dispose();
  }

  void _addNewSegment() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Segment Type'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: Types.values.length,
              itemBuilder: (BuildContext context, int index) {
                Types type = Types.values[index];
                return ListTile(
                  title: Text(type.toString().split('.').last),
                  onTap: () {
                    setState(() {
                      message.addSegment(type);
                    });
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _sendMessage() {
    BluetoothManager().sendMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose Message'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: message.segments.length + 1,
              itemBuilder: (context, index) {
                if (index == message.segments.length) {
                  return ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add New Segment'),
                    onTap: _addNewSegment,
                  );
                } else {
                  return ListTile(
                    title: EditField(
                      label: message.getSegmentType(index).name,
                      initialValue: message.getSegmentData(index),
                      onChanged: (newValue) {
                        setState(() {
                          message.setSegmentData(index, newValue);
                        });
                      },
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => setState(() {
                            message.removeSegment(index);
                          }),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: message.segments.isEmpty ? null : _sendMessage,
              child: const Text('Send Message'),
            ),
          ),
        ],
      ),
    );
  }
}