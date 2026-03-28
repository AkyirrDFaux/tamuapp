import 'dart:collection';

import '../info.dart';
import '../types.dart';

class Path {
  final List<int> indices;

  Path([List<int>? input]) : indices = List<int>.unmodifiable(input ?? []);

  int get length => indices.length;
  String get pathString => indices.join('.');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is Path && _listEquals(indices, other.indices));

  @override
  int get hashCode => Object.hashAll(indices);

  @override
  String toString() => indices.isEmpty ? "Root" : pathString;

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) if (a[i] != b[i]) return false;
    return true;
  }
}

class Reference {
  final bool isGlobal;
  final int net;
  final int group;
  final int device;
  final Path location;
  final String fullAddress;

  /// Internal constructor to centralize logic and string caching
  Reference._internal({
    required this.isGlobal,
    required this.net,
    required this.group,
    required this.device,
    required this.location,
  }) : fullAddress = isGlobal
      ? "$net.$group.$device${location.indices.isNotEmpty ? '.${location.pathString}' : ''}"
      : "L${location.indices.isNotEmpty ? '.${location.pathString}' : ''}";

  /// Global Constructor (Implicitly Global)
  /// Usage: Reference(0, 1, 10, Path([1, 2]))
  Reference(int net, int group, int device, [Path? path])
      : this._internal(
    isGlobal: true,
    net: net,
    group: group,
    device: device,
    location: path ?? Path(),
  );

  /// Local Constructor (Explicitly Local)
  /// Usage: Reference.local(Path([1, 2]))
  Reference.local([Path? path])
      : this._internal(
    isGlobal: false,
    net: 0,
    group: 0,
    device: 0,
    location: path ?? Path(),
  );

  /// Empty/Invalid Reference
  factory Reference.empty() => Reference.local();

  int get metadata => (isGlobal ? 0x80 : 0x00) | (location.length & 0x7F);

  factory Reference.fromList(List<int> bytes) {
    if (bytes.isEmpty) return Reference.local();

    final meta = bytes[0];
    final isGlobal = (meta & 0x80) != 0;
    final pathLen = meta & 0x7F;

    final n = bytes.length > 1 ? bytes[1] : 0;
    final g = bytes.length > 2 ? bytes[2] : 0;
    final d = bytes.length > 3 ? bytes[3] : 0;

    List<int> pathSegments = [];
    if (bytes.length > 4) {
      final end = 4 + pathLen;
      pathSegments = bytes.sublist(4, end > bytes.length ? bytes.length : end);
    }

    return Reference._internal(
      isGlobal: isGlobal,
      net: n,
      group: g,
      device: d,
      location: Path(pathSegments),
    );
  }

  List<int> toBytes() {
    return [
      metadata,
      net,
      group,
      device,
      ...location.indices,
    ];
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