import 'dart:math';

import 'package:flutter/material.dart';
import '../flags.dart';
import '../object/object_manager.dart';
import 'coord2d_dialog.dart';
import 'flag_dialog.dart';
import 'single_value_dialog.dart';
import 'map_dialog.dart';
import 'vector2d_dialog.dart';
import 'colour_dialog.dart';
import '../object/object.dart';

class EditableField extends StatefulWidget {
  final String label;
  final dynamic initialValue;
  final ValueChanged<dynamic> onChanged;

  const EditableField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<EditableField> {
  late dynamic _newValue;

  @override
  void initState() {
    super.initState();
    _newValue = widget.initialValue;
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        if (widget.initialValue is List<MapEntry<int, int>>) {
          return MapDialog(
            label: widget.label,
            initialValue: widget.initialValue,
            onChanged: (newValue) {
              setState(() {
                _newValue = newValue;
              });
              widget.onChanged(newValue);
            },
          );
        } else if (widget.initialValue is Vector2D) {
          return Vector2DDialog(
            label: widget.label,
            initialValue: widget.initialValue,
            onChanged: (newValue) {
              setState(() {
                _newValue = newValue;
              });
              widget.onChanged(newValue);
            },
          );
        }
        else if (widget.initialValue is Coord2D) {
          return Coord2DDialog(
            label: widget.label,
            initialValue: widget.initialValue,
            onChanged: (newValue) {
              setState(() {
                _newValue = newValue;
              });
              widget.onChanged(newValue);
            },
          );
        }
        else if (widget.initialValue is Colour) {
          return ColourDialog(
            label: widget.label,
            initialValue: widget.initialValue,
            onChanged: (newValue) {
              setState(() {
                _newValue = newValue;
              });
              widget.onChanged(newValue);
            },
          );
        } else if (widget.initialValue is FlagClass) {
          return FlagDialog(
            label: widget.label,
            initialValue: widget.initialValue,
            onChanged: (newValue) {
              setState(() {
                _newValue = newValue;
              });
              widget.onChanged(newValue);
            },
          );
        } else {
          return SingleValueDialog(
            label: widget.label,
            initialValue: widget.initialValue,
            onChanged: (newValue) {
              setState(() {
                _newValue = newValue;
              });
              widget.onChanged(newValue);
            },
          );
        }
      },
    );
  }

  String _getDisplayValue() {
    if (_newValue is List<MapEntry<int, int>>) {
      // Format the list of MapEntry for display, each on a new line
      return _newValue.map((entry) {
        Object? obj;
        try {
          obj = ObjectManager().objects.firstWhere(
                (obj) => obj.id == entry.value,
          );
        } catch (e) {
          obj = null;
        }
        if (obj == null) {
          return "${entry.key}, ${entry.value} : (None)";
        } else {
          return "${entry.key}, ${entry.value} : ${obj.name} (${obj.type
              .name})";
        }
      }).join('\n');
    } else if (_newValue is Coord2D) {
      return "${_newValue.Position}, Angle: ${atan2(_newValue.Rotation.Y,_newValue.Rotation.X) * 180 / pi}°";
    } else {
      return _newValue.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${widget.label}: ${_getDisplayValue()}',
            // Add the following line to allow multiline text
            textAlign: TextAlign.start,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _showEditDialog(context),
        ),
      ],
    );
  }
}