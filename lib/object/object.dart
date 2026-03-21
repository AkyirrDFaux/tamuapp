import 'dart:collection';

import '../info.dart';
import '../types.dart';

class Path {
  final List<int> indices;
  final String pathString;

  Path([List<int>? input])
      : indices = List<int>.unmodifiable(input ?? []),
        pathString = (input ?? []).join('.');

  int get length => indices.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is Path && pathString == other.pathString);

  @override
  int get hashCode => pathString.hashCode;

  @override
  String toString() => pathString.isEmpty ? "Root" : pathString;
}

class Reference {
  final int net;
  final int group;
  final int device;
  final Path location;

  // Caching the full string for fast Map lookups and comparison
  final String fullAddress;

  Reference(this.net, this.group, this.device, [Path? path])
      : location = path ?? Path(),
        fullAddress = "$net.$group.$device${(path != null && path.indices.isNotEmpty) ? '.${path.pathString}' : ''}";

  /// Constructor to build from a raw list of bytes [Net, Group, Device, ...Path...]
  factory Reference.fromList(List<int> values) {
    if (values.length < 3) return Reference(0, 0, 0);

    final net = values[0];
    final group = values[1];
    final device = values[2];

    // Anything after index 2 is the local Path
    final pathSegments = values.sublist(3);
    return Reference(net, group, device, Path(pathSegments));
  }

  /// Helper to get the raw byte representation for sending to MCU
  List<int> toBytes() {
    return [net, group, device, ...location.indices];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is Reference && fullAddress == other.fullAddress);

  @override
  int get hashCode => fullAddress.hashCode;

  @override
  String toString() => fullAddress;
}

// Extension to help with list comparison (requires no extra packages)
extension IterableExtension<T> on Iterable<T> {
  bool all(bool Function(T element) test) {
    for (T element in this) {
      if (!test(element)) return false;
    }
    return true;
  }
}

class ValueEntry {
  final Types type;
  final Path path; // Switched from Reference to Path
  dynamic data;

  ValueEntry({
    required this.type,
    required this.path,
    required this.data,
  });
}

class NodeObject {
  final ObjectTypes type;
  final Reference id; // Global Address (Net, Group, Device)
  String name;

  // UPDATED: Now uses ObjectInfo to bundle Flags and RunTiming
  final ObjectInfo info;

  // The key is the Path string (e.g., "0", "1.2")
  final SplayTreeMap<String, ValueEntry> values = SplayTreeMap<String, ValueEntry>();

  NodeObject({
    required this.type,
    required this.id,
    this.name = "Unnamed",
    ObjectInfo? info,
  }) : info = info ?? ObjectInfo();

  List<ValueEntry> get sortedValues => values.values.toList();

  /// Updates a value using a local Path
  void updateValue(Path path, Types type, dynamic data) {
    values[path.pathString] = ValueEntry(
      type: type,
      path: path,
      data: data,
    );

    print("OBJECT ${id.fullAddress} | Update Path: ${path.pathString} | Total Keys: ${values.length}");
  }

  /// Helper to check if object is currently ignored by the MCU
  bool get isInactive => info.flags.has(Flags.inactive);

  /// Helper to set the object to run once on the next MCU cycle
  void triggerRunOnce() {
    info.flags.add(Flags.runOnce);
  }
}

class Vector2D {
  double X = 0;
  double Y = 0;

  Vector2D(this.X, this.Y);
  @override
  String toString() {
    return 'Vector2D(X: $X, Y: $Y)';
  }
}

class Vector3D {
  double X = 0;
  double Y = 0;
  double Z = 0;

  Vector3D(this.X, this.Y,this.Z);
  @override
  String toString() {
    return 'Vector3D(X: $X, Y: $Y, Z: $Z)';
  }
}

class Coord2D {
  Vector2D Position = Vector2D(0, 0);
  Vector2D Rotation = Vector2D(1, 0);

  Coord2D(this.Position, this.Rotation);

  @override
  String toString() {
    return 'Coord2D(Position: $Position, Rotation: $Rotation)';
  }
}

class Coord3D {
  Vector3D Position = Vector3D(0, 0, 0);
  Vector3D Rotation = Vector3D(1, 0, 0);

  Coord3D(this.Position, this.Rotation);

  @override
  String toString() {
    return 'Coord3D(Position: $Position, Rotation: $Rotation)';
  }
}

class Colour {
  int R = 0;
  int G = 0;
  int B = 0;
  int A = 0;
  Colour(this.R, this.G, this.B, this.A);

  @override
  String toString() {
    return 'Colour(R: $R, G: $G, B: $B, A: $A)';
  }
}