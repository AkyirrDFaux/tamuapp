import 'package:flutter/material.dart';
import '../flags.dart'; // Assuming this is where your FlagClass is defined

class FlagDialog extends StatefulWidget {
  final String label;
  final FlagClass initialValue;
  final ValueChanged<FlagClass> onChanged;

  const FlagDialog({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  _FlagDialogState createState() => _FlagDialogState();
}

class _FlagDialogState extends State<FlagDialog> {
  late FlagClass _currentValue;
  late List<bool> _checkboxValues;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _checkboxValues = List.generate(8, (index) => _currentValue.isSet(index));
  }

  void _onCheckboxChanged(int index, bool value) {
    setState(() {
      _checkboxValues[index] = value;
      if (value) {
        _currentValue.set(index);
      } else {
        _currentValue.clear(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.label}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(8, (index) {
            return CheckboxListTile(
              title: Text(Flags.values[index+1].name),
              value: _checkboxValues[index],
              onChanged: (bool? value) {
                if (value != null) {
                  _onCheckboxChanged(index, value);
                }
              },
            );
          }),
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
            widget.onChanged(_currentValue);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}