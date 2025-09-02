import 'package:flutter/material.dart';
import '../flags.dart';
import '../types.dart';
import 'coord2d_dialog.dart';
import 'flag_dialog.dart';
import 'single_value_dialog.dart';
import 'map_dialog.dart';
import 'vector2d_dialog.dart';
import 'colour_dialog.dart';
import 'value_dialog.dart'; // Import the new dialog
import '../values.dart';

// A type definition for a function that builds a dialog widget.
typedef DialogBuilder = Widget Function(
    String label,
    dynamic initialValue,
    ValueChanged<dynamic> onChanged,
    );

class EditField extends StatefulWidget {
  final String label;
  final dynamic initialValue;
  final ValueChanged<dynamic> onChanged;
  final Types type;

  const EditField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    required this.type,
  });

  @override
  State<EditField> createState() => _EditFieldState();
}

class _EditFieldState extends State<EditField> {
  // A map that associates editor types with their specific dialog builders.
  static final Map<Types, DialogBuilder> _dialogBuilders = {
    Types.IDList: (label, initialValue, onChanged) => MapDialog(
      label: label,
      initialValue: initialValue,
      onChanged: onChanged,
    ),
    Types.Vector2D: (label, initialValue, onChanged) => Vector2DDialog(
      label: label,
      initialValue: initialValue,
      onChanged: onChanged,
    ),
    Types.Coord2D: (label, initialValue, onChanged) => Coord2DDialog(
      label: label,
      initialValue: initialValue,
      onChanged: onChanged,
    ),
    Types.Colour: (label, initialValue, onChanged) => ColourDialog(
      label: label,
      initialValue: initialValue,
      onChanged: onChanged,
    ),
    Types.Flags: (label, initialValue, onChanged) => FlagDialog(
      label: label,
      initialValue: initialValue,
      onChanged: onChanged,
    ),
  };

  void _handleValueChange(dynamic newValue) {
    widget.onChanged(newValue);
  }

  void _showEditDialog(BuildContext context) {
    // Check for the special enum case first.
    if (isInValueEnum(widget.type)) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return ValueDialog(
            label: widget.label,
            initialValue: widget.initialValue,
            onChanged: _handleValueChange,
            type: widget.type,
          );
        },
      );
      return; // Stop further execution
    }

    // Find the correct dialog builder from the map using the widget's type, or use the default.
    final builder = _dialogBuilders[widget.type] ??
            (label, initialValue, onChanged) => SingleValueDialog(
          label: label,
          initialValue: initialValue,
          onChanged: onChanged,
        );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return builder(
          widget.label,
          widget.initialValue,
          _handleValueChange,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () => _showEditDialog(context),
    );
  }
}

