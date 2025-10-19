import 'dart:math';
import 'package:flutter/material.dart';

import '../object/object.dart';
import '../object/object_manager.dart';
import '../types.dart';
import '../values.dart';

class ValueDisplay extends StatelessWidget {
  /// The data to be displayed. Can be of any type (e.g., String, int, List, Coord2D).
  final dynamic value;

  /// Optional enum to specify a custom display format for the value.
  final Types type;

  const ValueDisplay({
    super.key,
    required this.type,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    // --- NEW: Handle the Colour type, which returns a Row widget ---
    if (type == Types.Colour && value is Colour) {
      return _formatColour(value);
    }

    // For all other types, return a Text widget as before
    return Text(
      _getDisplayValue(),
    );
  }

  /// Formats the `value` into a displayable string based on its type.
  String _getDisplayValue() {
    // Check for null value first
    if (value == null) {
      return "(None)";
    }

    // Handle integer values that map to a string enum
    if (value is int && isInValueEnum(type)) {
      return getValueEnum(type, value) ?? "Invalid Index: $value";
    }

    // Use the explicit type if provided
    switch (type) {
      case Types.ID:
        return _formatId(value);
      case Types.IDList:
        return _formatObjectList(value);
      case Types.Coord2D:
        return _formatCoord2D(value);
    // The Colour type is now handled in the build method,
    // but we can leave its string representation here as a fallback.
      case Types.Colour:
        return value.toString();
      default:
      // Fallback to default behavior if the type isn't a special case
        return value.toString();
    }
  }

  // --- NEW: Method to create a widget for the Colour type ---
  /// Formats a Colour object into a Row with a colored circle and text.
  Widget _formatColour(Colour colourValue) {
    return Row(
      mainAxisSize: MainAxisSize.min, // To keep the row from expanding
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(right: 8.0),
          decoration: BoxDecoration(
            color: Color.fromARGB(
              colourValue.A,
              colourValue.R,
              colourValue.G,
              colourValue.B,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
        ),
        Text(colourValue.toString()), // e.g., "Colour(R: 255, G: 0, B: 0, A: 255)"
      ],
    );
  }

  /// Formats a list of map entries representing objects.
  String _formatObjectList(dynamic listValue) {
    if (listValue is! List<MapEntry<int, int>>) {
      return "Invalid data for object list";
    }
    if (listValue.isEmpty) {
      return "(Empty List)";
    }

    // Sort the list by the key (index) to ensure correct order.
    listValue.sort((a, b) => a.key.compareTo(b.key));

    final List<String> displayLines = [];
    int expectedKey = 0;

    for (final entry in listValue) {
      // Add placeholders for missing consecutive items.
      while (expectedKey < entry.key) {
        displayLines.add("-");
        expectedKey++;
      }

      dynamic obj;
      try {
        obj = ObjectManager().objects.firstWhere(
              (o) => o.id == entry.value & 0xFFFFFF00,
        );
      } catch (e) {
        obj = null;
      }

      final formattedId = _formatId(entry.value);

      if (obj == null) {
        displayLines.add("$formattedId : (None)");
      } else {
        final typeName = obj.type.toString().split('.').last;
        displayLines.add("$formattedId : ${obj.name} ($typeName)");
      }
      expectedKey++;
    }

    return displayLines.join('\n');
  }

  /// Formats the ID into a string representation 'x.y'.
  String _formatId(int id) {
    final x = id >> 8; // Shift to the right by 8 to get the higher bits
    final y = id & 0xFF; // Use a bitwise AND with 0xFF to get the lower 8 bits
    return '$x.$y';
  }


  /// Formats a Coord2D object.
  String _formatCoord2D(dynamic coordValue) {
    if (coordValue is! Coord2D) {
      return "Invalid data for coordinates";
    }
    final angle = atan2(coordValue.Rotation.Y, coordValue.Rotation.X) * 180 / pi;
    return "${coordValue.Position}, Angle: ${angle.toStringAsFixed(2)}°";
  }
}
