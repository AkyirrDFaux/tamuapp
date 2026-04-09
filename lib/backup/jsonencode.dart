import 'package:tamuapp/types.dart';
import 'package:tamuapp/values.dart';

import '../info.dart';
import '../object/object.dart';

dynamic valueToJson(Types type, dynamic data) {
  if (data == null) return null;

  // 1. Handle Named Enums (Operation, Board, etc.)
  if (isInValueEnum(type)) {
    int index = (data is int) ? data : (data as dynamic).index;
    return getValueEnum(type, index) ?? index; // Fallback to int if name not found
  }

  switch (type) {
    case Types.PortType:
    // Uses your PortFlags bitmask logic
      return PortFlags.getActiveFlags(data as int);

    case Types.Vector2D:
      return {"x": data.X, "y": data.Y};
    case Types.Vector3D:
      return {"x": data.X, "y": data.Y, "z": data.Z};
    case Types.Coord2D:
      return {
        "pos": {"x": data.Position.X, "y": data.Position.Y},
        "rot": {"x": data.Rotation.X, "y": data.Rotation.Y}
      };
    case Types.Coord3D:
      return {
        "pos": {"x": data.Position.X, "y": data.Position.Y, "z": data.Position.Z},
        "rot": {"x": data.Rotation.X, "y": data.Rotation.Y, "z": data.Rotation.Z}
      };
    case Types.Colour:
      return {"r": data.R, "g": data.G, "b": data.B, "a": data.A};
    case Types.Reference:
      return data is Reference ? data.globalAddress : data.toString();
    case Types.ObjectInfo:
      if (data is ObjectInfo) {
        return {
          "flags": data.flags.activeNames, // ["auto", "runLoop"] instead of 17
          "runPeriod": data.runPeriod,
          "runPhase": data.runPhase
        };
      }
      return data;
    case Types.Pin:
      if (data is (int, String)) {
        // If the port is null character (0), just save the index to keep it clean
        final int portCode = data.$2.isNotEmpty ? data.$2.codeUnitAt(0) : 0;
        if (portCode == 0) return data.$1;

        return {
          "index": data.$1,
          "port": data.$2,
        };
      }
      return data;
    default:
      return data;
  }
}

dynamic valueFromJson(Types type, dynamic json) {
  if (json == null) return null;

  // 1. Handle Named Enums (String -> Index)
  if (isInValueEnum(type) && json is String) {
    List<String>? names = typeToValueNames[type];
    int idx = names?.indexOf(json) ?? -1;
    if (idx != -1) return idx;
  }

  switch (type) {
    case Types.PortType:
      if (json is List) {
        // Reconstruct bitmask from list of strings
        int mask = 0;
        for (var flagName in json) {
          final entry = PortFlags.names.entries
              .firstWhere((e) => e.value == flagName, orElse: () => const MapEntry(0, ""));
          mask |= entry.key;
        }
        return mask;
      }
      return json;

    case Types.Vector2D:
      return Vector2D(json['x'].toDouble(), json['y'].toDouble());
    case Types.Vector3D:
      return Vector3D(json['x'].toDouble(), json['y'].toDouble(), json['z'].toDouble());
    case Types.Coord2D:
      return Coord2D(
        Vector2D(json['pos']['x'].toDouble(), json['pos']['y'].toDouble()),
        Vector2D(json['rot']['x'].toDouble(), json['rot']['y'].toDouble()),
      );
    case Types.Coord3D:
      return Coord3D(
        Vector3D(json['pos']['x'].toDouble(), json['pos']['y'].toDouble(), json['pos']['z'].toDouble()),
        Vector3D(json['rot']['x'].toDouble(), json['rot']['y'].toDouble(), json['rot']['z'].toDouble()),
      );
    case Types.Colour:
      return Colour(json['r'], json['g'], json['b'], json['a']);
    case Types.Reference:
      return Reference.parse(json.toString());
    case Types.ObjectInfo:
      final List<dynamic> flagNames = json['flags'] ?? [];
      final FlagClass inflatedFlags = FlagClass(0);

      for (var name in flagNames) {
        try {
          // Find the enum by its string name (e.g., "auto")
          final flag = Flags.values.firstWhere((f) => f.name == name);
          if (flag != Flags.none) inflatedFlags.add(flag);
        } catch (e) {
          // Handle "none" or unknown strings gracefully
        }
      }

      return ObjectInfo(
        flags: inflatedFlags,
        runPeriod: json['runPeriod'] ?? 0,
        runPhase: json['runPhase'] ?? 0,
      );
    case Types.Pin:
      if (json is Map) {
        return (
        (json['index'] as num).toInt(),
        (json['port'] as String? ?? "")
        );
      }
      if (json is int) {
        // Fallback for cases where only the index was saved (port 0)
        return (json, "");
      }
      return (0, "");
    default:
      return json;
  }
}