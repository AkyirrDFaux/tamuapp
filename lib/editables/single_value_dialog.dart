import 'package:flutter/material.dart';

class SingleValueDialog extends StatefulWidget {
  final String label;
  final dynamic initialValue;
  final ValueChanged<dynamic> onChanged;

  const SingleValueDialog({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<SingleValueDialog> createState() => _SingleValueDialogState();
}

class _SingleValueDialogState extends State<SingleValueDialog> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.label}'),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Enter new ${widget.label}',
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Save'),
          onPressed: () {
            dynamic newValue;
            if (widget.initialValue is int) {
              newValue = int.tryParse(controller.text);
            } else if (widget.initialValue is double) {
              newValue = double.tryParse(controller.text);
            } else if (widget.initialValue is String) {
              newValue = controller.text;
            }
            if (newValue != null) {
              widget.onChanged(newValue);
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}