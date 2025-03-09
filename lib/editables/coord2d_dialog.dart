import 'dart:math';

import 'package:flutter/material.dart';
import '../object/object.dart'; // Assuming this is where Vector2D is defined

class Coord2DDialog extends StatefulWidget {
  final String label;
  final Coord2D initialValue;
  final ValueChanged<Coord2D> onChanged;

  const Coord2DDialog({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<Coord2DDialog> createState() => _Vector2DDialogState();
}

class _Vector2DDialogState extends State<Coord2DDialog> {
  late TextEditingController xController;
  late TextEditingController yController;
  late TextEditingController angleController;

  @override
  void initState() {
    super.initState();
    xController = TextEditingController(text: widget.initialValue.Position.X.toString());
    yController = TextEditingController(text: widget.initialValue.Position.Y.toString());
    angleController = TextEditingController(text:
    (atan2(widget.initialValue.Rotation.Y,widget.initialValue.Rotation.X) * 180 / pi).toString());
  }

  @override
  void dispose() {
    xController.dispose();
    yController.dispose();
    angleController.dispose();
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
          TextField(
            controller: angleController,
            decoration: const InputDecoration(hintText: 'Angle [deg]'),
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
            double? newAngle = double.tryParse(angleController.text);
            if (newX != null && newY != null && newAngle != null) {
              newAngle = newAngle / 180 * pi;
              widget.onChanged(Coord2D(Vector2D(newX, newY), Vector2D(cos(newAngle),sin(newAngle))));
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}