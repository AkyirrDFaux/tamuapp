import 'dart:math';
import 'package:flutter/material.dart';

import '../info.dart';
import 'object.dart';
import 'object_manager.dart';
import '../types.dart';
import '../values.dart';

class ValueDisplay extends StatelessWidget {
  final dynamic value;
  final Types type;

  const ValueDisplay({
    super.key,
    required this.type,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    TextStyle dataStyle = const TextStyle(
      fontSize: 15,
      color: Colors.white,
      fontWeight: FontWeight.w500,
    );

    if (value == null) {
      return Text("None",
          style: dataStyle.copyWith(color: Colors.white24, fontStyle: FontStyle.italic));
    }

    // 1. Handle ObjectInfo (New bundled type)
    if (type == Types.ObjectInfo && value is ObjectInfo) {
      return _buildObjectInfoSummary(value, theme);
    }

    // 2. Handle Enums / Named Types
    if (isInValueEnum(type) && value is int) {
      String name = getValueEnum(type, value) ?? "Unknown ($value)";
      return _buildEnumBadge(name, theme);
    }

    // 3. Special Widget Builders (Colour)
    if (type == Types.Colour && value is Colour) {
      return _buildColourRow(value, dataStyle);
    }

    if (type == Types.PortType && value is int) {
      // Get the list of active flag names
      final activeFlags = PortFlags.getActiveFlags(value);

      // Return a standard Text widget with the flags joined by a separator
      return Text(
        activeFlags.join(", "),
        style: dataStyle,
      );
    }

    // 4. Standard Text Output
    return Text(
      _getFormattedString(),
      style: dataStyle,
    );
  }

  String _getFormattedString() {
    switch (type) {
      case Types.Byte:
        if (value is int) {
          final hex = value.toRadixString(16).padLeft(2, '0').toUpperCase();
          return "$value (0x$hex)";
        }
        break;

      case Types.Bool:
        return (value == true || value == 1) ? "True" : "False";

      case Types.Number:
        if (value is num) return value.toStringAsFixed(2);
        break;

      case Types.Vector2D:
        if (value is Vector2D) return _formatVec2(value);
        break;

      case Types.Vector3D:
        if (value is Vector3D) return _formatVec3(value);
        break;

      case Types.Coord2D:
        if (value is Coord2D) {
          final angle = atan2(value.Rotation.Y, value.Rotation.X) * 180 / pi;
          return "${_formatVec2(value.Position)}, Angle: ${angle.toStringAsFixed(1)}°";
        }
        break;

      case Types.Coord3D:
        if (value is Coord3D) {
          return "Pos: [${_formatVec3(value.Position)}], Rot: [${_formatVec3(value.Rotation)}]";
        }
        break;

      default:
        return value.toString();
    }
    return value.toString();
  }

  // --- New Builders ---

  Widget _buildObjectInfoSummary(ObjectInfo info, ThemeData theme) {
    bool isInactive = info.flags.has(Flags.inactive);
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildEnumBadge("Timing: ${info.runTiming}ms", theme),
        if (isInactive)
          _buildEnumBadge("INACTIVE", theme, color: Colors.redAccent),
        Text(
          "Flags: ${info.flags}",
          style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  // --- Formatting Helpers ---

  String _formatVec2(Vector2D v) =>
      "X: ${v.X.toStringAsFixed(1)}, Y: ${v.Y.toStringAsFixed(1)}";

  String _formatVec3(Vector3D v) =>
      "X: ${v.X.toStringAsFixed(1)}, Y: ${v.Y.toStringAsFixed(1)}, Z: ${v.Z.toStringAsFixed(1)}";

  Widget _buildEnumBadge(String label, ThemeData theme, {Color? color}) {
    final activeColor = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: activeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: activeColor.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: activeColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildColourRow(Colour c, TextStyle baseStyle) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            color: Color.fromARGB(c.A, c.R, c.G, c.B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30),
          ),
        ),
        const SizedBox(width: 8),
        Text("RGBA(${c.R},${c.G},${c.B},${c.A})", style: baseStyle),
      ],
    );
  }
}