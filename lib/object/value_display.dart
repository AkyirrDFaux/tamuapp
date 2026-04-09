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

    // 1. Handle Reference (The new Global/Local logic)
    if (type == Types.Reference && value is Reference) {
      return _buildReferenceBadge(value, theme);
    }

    // 3. Handle ObjectInfo
    if (type == Types.ObjectInfo && value is ObjectInfo) {
      return _buildObjectInfoSummary(value, theme);
    }

    // 4. Handle PortNumber
    if (type == Types.PortNumber && value is int) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.settings_input_component, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          _buildEnumBadge("PORT $value", theme),
        ],
      );
    }

    // 5. Handle Enums / Named Types
    if (isInValueEnum(type) && value is int) {
      String name = getValueEnum(type, value) ?? "Unknown ($value)";
      return _buildEnumBadge(name, theme);
    }

    // 6. Handle Colour
    if (type == Types.Colour && value is Colour) {
      return _buildColourRow(value, dataStyle);
    }

    // 7. Handle PortType Flags
    if (type == Types.PortType && value is int) {
      final activeFlags = PortFlags.getActiveFlags(value);
      return Text(
        activeFlags.isEmpty ? "No Flags" : activeFlags.join(", "),
        style: dataStyle,
      );
    }
    /// 8. Handle Pin {Index, Port} Tuple
    if (type == Types.Pin && value is (int, String)) {
      // Check if Port is the null character (0) or empty
      final int portCode = value.$2.isNotEmpty ? value.$2.codeUnitAt(0) : 0;
      final String portLabel = portCode == 0 ? "" : value.$2;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 14, color: Colors.orangeAccent),
          const SizedBox(width: 4),
          _buildEnumBadge("PIN $portLabel${value.$1}", theme, color: Colors.orangeAccent),
        ],
      );
    }

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
      case Types.Integer:
        return value.toString();
      case Types.Vector2D:
        if (value is Vector2D) return _formatVec2(value);
        break;
      case Types.Vector3D:
        if (value is Vector3D) return _formatVec3(value);
        break;
      case Types.Coord2D:
        if (value is Coord2D) {
          final angle = atan2(value.Rotation.Y, value.Rotation.X) * 180 / pi;
          return "${_formatVec2(value.Position)}, ${angle.toStringAsFixed(1)}°";
        }
        break;
      case Types.Coord3D:
        if (value is Coord3D) {
          return "P: [${_formatVec3(value.Position)}], R: [${_formatVec3(value.Rotation)}]";
        }
        break;
      case Types.Text:
        return value.toString();
      default:
        return value.toString();
    }
    return value.toString();
  }

  // --- Builders & Helpers ---

  Widget _buildObjectInfoSummary(ObjectInfo info, ThemeData theme) {
    bool isInactive = info.flags.has(Flags.inactive);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildEnumBadge("${info.runPeriod}ms", theme),
        if (isInactive)
          _buildEnumBadge("INACTIVE", theme, color: Colors.redAccent),
        Text(
          "Flags: ${info.flags}",
          style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'monospace'),
        ),
      ],
    );
  }

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
        Text("RGBA(${c.R}, ${c.G}, ${c.B}, ${c.A})", style: baseStyle),
      ],
    );
  }

  Widget _buildReferenceBadge(Reference ref, ThemeData theme) {
    final bool isGlobal = ref.isGlobal;

    // Explicit vivid colors to avoid the "grayed out" theme defaults
    final Color globalColor = Colors.cyanAccent;
    final Color localColor = Colors.orangeAccent;

    final Color activeColor = isGlobal ? globalColor : localColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isGlobal ? Icons.public : Icons.shortcut,
          size: 14,
          color: activeColor,
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            // Increased opacity (0.15) for better visibility against dark backgrounds
            color: activeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: activeColor.withOpacity(0.3), width: 1),
          ),
          child: Text(
            ref.fullAddress,
            style: TextStyle(
              color: activeColor,
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}