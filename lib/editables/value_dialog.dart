import 'package:flutter/material.dart';
import '../types.dart';
import '../values.dart';

/// A dialog for selecting a value from a predefined list of strings (enum-like).
///
/// This dialog displays a dropdown menu of options derived from a `Types` enum value.
/// It expects an integer `initialValue` representing the index of the currently
/// selected option and uses `onChanged` to report the index of the new selection.
class ValueDialog extends StatefulWidget {
  final String label;
  final int initialValue; // The index of the selected value
  final ValueChanged<int> onChanged;
  final Types type;

  const ValueDialog({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    required this.type,
  });

  @override
  State<ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<ValueDialog> {
  late int _selectedValue;
  late final List<String> _options;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
    // Populate the dropdown options from the provided enum type.
    _options = [];
    int index = 0;
    while (true) {
      final value = getValueEnum(widget.type, index);
      if (value != null) {
        _options.add(value);
        index++;
      } else {
        // When getValueEnum returns null, we've collected all the options.
        break;
      }
    }
  }

  void _onConfirm() {
    widget.onChanged(_selectedValue);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.label}'),
      content: DropdownButton<int>(
        value: _selectedValue,
        // Ensure the dropdown can expand if the text is long.
        isExpanded: true,
        // Map the list of string options to a list of DropdownMenuItems.
        // The value of each item is its index in the list.
        items: _options.asMap().entries.map((entry) {
          int index = entry.key;
          String value = entry.value;
          return DropdownMenuItem<int>(
            value: index,
            child: Text(value),
          );
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            setState(() {
              _selectedValue = newValue;
            });
          }
        },
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          // Use a FilledButton for the primary action to make it stand out.
          child: const Text('Confirm'),
          onPressed: _onConfirm,
        ),
      ],
    );
  }
}
