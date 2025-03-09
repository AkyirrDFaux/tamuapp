import 'package:flutter/material.dart';
import '../object/object.dart'; // Assuming this is where Vector2D is defined

class Vector2DDialog extends StatefulWidget {
  final String label;
  final Vector2D initialValue;
  final ValueChanged<Vector2D> onChanged;

  const Vector2DDialog({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<Vector2DDialog> createState() => _Vector2DDialogState();
}

class _Vector2DDialogState extends State<Vector2DDialog> {
  late TextEditingController xController;
  late TextEditingController yController;

  @override
  void initState() {
    super.initState();
    xController = TextEditingController(text: widget.initialValue.X.toString());
    yController = TextEditingController(text: widget.initialValue.Y.toString());
  }

  @override
  void dispose() {
    xController.dispose();
    yController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.label}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: xController,
            decoration: const InputDecoration(hintText: 'X'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: yController,
            decoration: const InputDecoration(hintText: 'Y'),
            keyboardType: TextInputType.number,
          ),
        ],
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
            double? newX = double.tryParse(xController.text);
            double? newY = double.tryParse(yController.text);
            if (newX != null && newY != null) {
              widget.onChanged(Vector2D(newX, newY));
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}