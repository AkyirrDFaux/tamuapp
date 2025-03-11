import 'package:flutter/material.dart';
import '../object/object.dart'; // Assuming this is where Colour is defined

class ColourDialog extends StatefulWidget {
  final String label;
  final Colour initialValue;
  final ValueChanged<Colour> onChanged;

  const ColourDialog({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<ColourDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<ColourDialog> {
  late TextEditingController rController;
  late TextEditingController gController;
  late TextEditingController bController;
  late TextEditingController aController;

  @override
  void initState() {
    super.initState();
    rController = TextEditingController(text: widget.initialValue.R.toString());
    gController = TextEditingController(text: widget.initialValue.G.toString());
    bController = TextEditingController(text: widget.initialValue.B.toString());
    aController = TextEditingController(text: widget.initialValue.A.toString());
  }

  @override
  void dispose() {
    rController.dispose();
    gController.dispose();
    bController.dispose();
    aController.dispose();
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
            controller: rController,
            decoration: const InputDecoration(hintText: 'R'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: gController,
            decoration: const InputDecoration(hintText: 'G'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: bController,
            decoration: const InputDecoration(hintText: 'B'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: aController,
            decoration: const InputDecoration(hintText: 'A'),
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
            int? newR = int.tryParse(rController.text);
            int? newG = int.tryParse(gController.text);
            int? newB = int.tryParse(bController.text);
            int? newA = int.tryParse(aController.text);
            if (newR != null &&
                newG != null &&
                newB != null &&
                newA != null) {
              widget.onChanged(Colour(newR, newG, newB, newA));
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}