import 'dart:collection';

import '../info.dart';
import '../backup/jsonencode.dart';
import '../types.dart';

import 'dart:typed_data';

class Path {
  final Uint8List indices;

  Path([List<int>? input]) : indices = Uint8List.fromList(input ?? []);

  /// Creates a Path from a dot-separated string (e.g., "0.1.2")
  factory Path.fromString(String path) {
    if (path.isEmpty || path.toLowerCase() == "root") {
      return Path([]);
    }

    try {
      final List<int> parsed = path
          .split('.')
          .map((s) => int.parse(s))
          .toList();
      return Path(parsed);
    } catch (e) {
      // Fallback for malformed strings
      return Path([]);
    }
  }

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

  static bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
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

  // NEW: Address of the Node/Device only (e.g., "1.2.3")
  final String globalAddress;

  Reference._internal({
    required this.isGlobal,
    required this.net,
    required this.group,
    required this.device,
    required this.location,
  }) : fullAddress = isGlobal
      ? "$net.$group.$device${location.indices.isNotEmpty ? '.${location.pathString}' : ''}"
      : "L${location.indices.isNotEmpty ? '.${location.pathString}' : ''}",
        globalAddress = "$net.$group.$device"; // Fixed key for the device

  Reference(int net, int group, int device, [Path? path])
      : this._internal(
    isGlobal: true,
    net: net,
    group: group,
    device: device,
    location: path ?? Path(),
  );

  Reference.local([Path? path])
      : this._internal(
    isGlobal: false,
    net: 0,
    group: 0,
    device: 0,
    location: path ?? Path(),
  );

  /// Helper for 3-byte Net/Group/Device resolution
  factory Reference.fromNetGroupDevice(int n, int g, int d, [Path? path]) =>
      Reference(n, g, d, path);

  factory Reference.empty() => Reference.local();

  // The first byte of the C++ Reference struct: [GlobalBit:1][PathLen:7]
  int get metadata => (isGlobal ? 0x80 : 0x00) | (location.length & 0x7F);

  factory Reference.fromBytes(Uint8List bytes) {
    if (bytes.length < 4) return Reference.empty();

    final meta = bytes[0];
    final isGlobal = (meta & 0x80) != 0;
    final pathLen = meta & 0x7F;

    final n = bytes[1];
    final g = bytes[2];
    final d = bytes[3];

    List<int> pathSegments = [];
    if (pathLen > 0 && bytes.length > 4) {
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

  factory Reference.parse(String address) {
    final parts = address.split('.');
    if (parts.length < 3) return Reference(0, 0, 0, Path([]));

    int net = int.tryParse(parts[0]) ?? 0;
    int group = int.tryParse(parts[1]) ?? 0;
    int device = int.tryParse(parts[2]) ?? 0;

    // Everything after the first 3 parts is the internal path
    List<int> pathIndices = [];
    if (parts.length > 3) {
      pathIndices = parts.sublist(3)
          .map((p) => int.tryParse(p) ?? 0)
          .toList();
    }

    return Reference(net, group, device, Path(pathIndices));
  }

  /// Returns a contiguous buffer matching the C++ Reference struct layout
  Uint8List toBytes() {
    final result = Uint8List(4 + location.length);
    result[0] = metadata;
    result[1] = net;
    result[2] = group;
    result[3] = device;

    if (location.length > 0) {
      result.setRange(4, 4 + location.length, location.indices);
    }

    return result;
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
  final Path path;
  dynamic data;

  // NEW: Flags matching the C++ Header bitmask
  bool isReadOnly;
  bool isSetupCall;

  ValueEntry({
    required this.type,
    required this.path,
    required this.data,
    this.isReadOnly = false,
    this.isSetupCall = false,
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
  /// Updates a value using a local Path, including Read-Only and Setup-Call flags
  void updateValue(Path path, Types type, dynamic data, {bool isReadOnly = false, bool isSetupCall = false}) {
    values[path.pathString] = ValueEntry(
      type: type,
      path: path,
      data: data,
      isReadOnly: isReadOnly,
      isSetupCall: isSetupCall,
    );

    print("OBJECT ${id.fullAddress} | Update Path: ${path.pathString} | RO: $isReadOnly | Setup: $isSetupCall");
  }

  /// Helper to check if object is currently ignored by the MCU
  bool get isInactive => info.flags.has(Flags.inactive);

  /// Helper to set the object to run once on the next MCU cycle
  void triggerRunOnce() {
    info.flags.add(Flags.runOnce);
  }

  // In NodeObject class (or as an extension)
  Map<String, dynamic> toBackupJson() {
    return {
      "id": id.globalAddress,
      "name": name,
      "type": type.name,
      // Use valueToJson for the ObjectInfo structure
      "info": valueToJson(Types.ObjectInfo, info),
      "values": values.values.map((v) {
        return {
          "path": v.path.pathString,
          "type": v.type.name,
          // Use our symmetric helper to handle Vector2D, Enums, etc.
          "data": valueToJson(v.type, v.data),
          "meta": {
            "readOnly": v.isReadOnly,
            "setupCall": v.isSetupCall
          }
        };
      }).toList(),
    };
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