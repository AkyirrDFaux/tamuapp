import 'dart:typed_data';
import 'dart:convert';

import '../values.dart';
import '../functions.dart';
import '../info.dart';
import '../object/object.dart';
import '../types.dart';

class Message {
  List<ValueEntry> valueEntries;

  Message({List<ValueEntry>? valueEntries}) : valueEntries = valueEntries ?? [];

  // factory CAN access static methods
  factory Message.fromBytes(Uint8List data) {
    if (data.length < 4) return Message();

    final byteData = ByteData.sublistView(data);
    final totalSize = byteData.getUint16(0, Endian.little);
    final headerCount = byteData.getUint16(2, Endian.little);

    // Safety: Ensure we don't overread if the buffer is truncated
    if (data.length < totalSize) return Message();

    int hPtr = 4;
    int dPtr = 4 + (headerCount * 4);

    final entries = <ValueEntry>[];
    List<int> currentPath = [];
    Map<int, int> depthCounters = {};

    for (int i = 0; i < headerCount; i++) {
      final type = Types.fromValue(data[hPtr]);
      final int depth = data[hPtr + 1];
      final int length = byteData.getUint16(hPtr + 2, Endian.little);

      // --- PATH RECONSTRUCTION ---
      while (currentPath.length > depth) {
        currentPath.removeLast();
      }

      int currentIndex = depthCounters[depth] ?? 0;

      if (currentPath.length <= depth) {
        currentPath.add(currentIndex);
      } else {
        currentPath[depth] = currentIndex;
      }

      depthCounters[depth] = currentIndex + 1;
      depthCounters.removeWhere((key, value) => key > depth);

      // --- DATA EXTRACTION ---
      if (dPtr + length <= data.length) {
        final rawData = data.sublist(dPtr, dPtr + length);

        entries.add(ValueEntry(
          type: type,
          path: Path(List<int>.from(currentPath)), // Snapshot of current path
          data: deserializeRaw(type, rawData),
        ));

        dPtr += length;
      }
      hPtr += 4;
    }

    // Pass the populated list to the constructor
    return Message(valueEntries: entries);
  }

  /// Helper to add a segment by creating a ValueEntry
  void addSegment(Types type, dynamic data, {List<int>? pathIndices}) {
    valueEntries.add(ValueEntry(
      type: type,
      path: Path(pathIndices ?? []),
      data: data,
    ));
  }

  /// The Flutter equivalent of C++ CreateMessage()
  Uint8List pack() {
    int headerCount = valueEntries.length;
    int headerAreaSize = headerCount * 4; // Transfer Header: Type(1), Depth(1), Length(2)
    int prefixSize = 4;

    // 1. Pre-serialize to calculate total size
    List<Uint8List> payloads = [];
    int totalPayloadSize = 0;

    for (var entry in valueEntries) {
      // Ensure _serializeData handles your specific Types (int, float, Text, etc.)
      Uint8List d = _serializeData(entry.type, entry.data);
      payloads.add(d);
      totalPayloadSize += d.length;
    }

    Uint8List buffer = Uint8List(prefixSize + headerAreaSize + totalPayloadSize);
    ByteData view = ByteData.view(buffer.buffer);

    // 2. Write Prefix (Total Length and Segment Count)
    view.setUint16(0, buffer.length, Endian.little);
    view.setUint16(2, headerCount, Endian.little);

    int hPtr = prefixSize;
    int dPtr = prefixSize + headerAreaSize;

    // 3. Pack Headers and Data
    for (int i = 0; i < headerCount; i++) {
      final entry = valueEntries[i];
      final data = payloads[i];

      // Write Type byte
      buffer[hPtr] = entry.type.value;

      // Write Depth byte (The length of the local path indices)
      // For a root-level segment, path.length is 0.
      buffer[hPtr + 1] = entry.path.indices.length;

      // Write Data Length (2 bytes)
      view.setUint16(hPtr + 2, data.length, Endian.little);

      hPtr += 4;

      // Write Payload Data
      if (data.isNotEmpty) {
        buffer.setRange(dPtr, dPtr + data.length, data);
        dPtr += data.length;
      }
    }

    return buffer;
  }

  Uint8List _serializeData(Types type, dynamic data) {
    if (data == null) return Uint8List(0);

    void packFixed(ByteData view, int offset, dynamic val) {
      int fixedVal = ((val as num).toDouble() * 65536.0).round();
      view.setInt32(offset, fixedVal, Endian.little);
    }

    void packInt32(ByteData view, int offset, int val) {
      view.setInt32(offset, val, Endian.little);
    }

    switch (type) {
      case Types.ObjectInfo:
        if (data is ObjectInfo) {
          // [FlagByte, TimingByte]
          return Uint8List.fromList([data.flags.value & 0xFF, data.runTiming & 0xFF]);
        }
        return Uint8List(2);

      case Types.Bool:
        return Uint8List.fromList([(data == true || data == 1) ? 1 : 0]);

      case Types.Function:
        int val = (data is Functions) ? data.value : (data as int);
        return Uint8List.fromList([val & 0xFF]);

      case Types.ObjectType:
        int val = (data is ObjectTypes) ? data.value : (data as int);
        return Uint8List.fromList([val & 0xFF]);

      case Types.Integer:
      case Types.PortType:
        final b = Uint8List(4);
        packInt32(ByteData.view(b.buffer), 0, data as int);
        return b;

      case Types.Number:
        final b = Uint8List(4);
        packFixed(ByteData.view(b.buffer), 0, data);
        return b;

      case Types.Vector2D:
        final b = Uint8List(8);
        final view = ByteData.view(b.buffer);
        packFixed(view, 0, data.X);
        packFixed(view, 4, data.Y);
        return b;

      case Types.Vector3D:
        final b = Uint8List(12);
        final view = ByteData.view(b.buffer);
        packFixed(view, 0, data.X);
        packFixed(view, 4, data.Y);
        packFixed(view, 8, data.Z);
        return b;

      case Types.Coord2D:
        final b = Uint8List(16);
        final view = ByteData.view(b.buffer);
        packFixed(view, 0, data.Position.X);
        packFixed(view, 4, data.Position.Y);
        packFixed(view, 8, data.Rotation.X);
        packFixed(view, 12, data.Rotation.Y);
        return b;

      case Types.Coord3D:
        final b = Uint8List(24);
        final view = ByteData.view(b.buffer);
        packFixed(view, 0, data.Position.X);
        packFixed(view, 4, data.Position.Y);
        packFixed(view, 8, data.Position.Z);
        packFixed(view, 12, data.Rotation.X);
        packFixed(view, 16, data.Rotation.Y);
        packFixed(view, 20, data.Rotation.Z);
        return b;

      case Types.Text:
        String str = data is String ? data : data.toString();
        return Uint8List.fromList(utf8.encode(str));

      case Types.Reference:
        if (data is Reference) return Uint8List.fromList(data.toBytes());
        if (data is List<int>) return Uint8List.fromList(data);
        return Uint8List(0);

      case Types.Colour:
        return Uint8List.fromList([data.R, data.G, data.B, data.A]);

      case Types.Pin:
      // Matches: struct Pin { uint8_t Number; char Port; }
        if (data is int) return Uint8List.fromList([data & 0xFF, 0]);
        // If data is a custom Pin object, you'd pull data.Number and data.Port
        return Uint8List.fromList([0, 0]);

      case Types.Board:
      case Types.Sensor:
      case Types.PortDriver:
      case Types.AccGyr:
      case Types.Geometry2D:
      case Types.GeometryOperation:
      case Types.Operation:
      case Types.Program:
      case Types.LocalFunction:
      case Types.Display:
      case Types.Byte:
      case Types.Type:
      case Types.Status:
      case Types.Input:
        int val = (data is Enum) ? (data as dynamic).index : (data as int);
        return Uint8List.fromList([val & 0xFF]);

      default:
        if (data is Uint8List) return data;
        return Uint8List(0);
    }
  }

  static dynamic deserializeRaw(Types type, Uint8List raw) {
    if (raw.isEmpty) return null;

    final view = ByteData.view(raw.buffer, raw.offsetInBytes, raw.length);

    double toFixed(int offset) {
      if (offset + 4 > raw.length) return 0.0;
      return view.getInt32(offset, Endian.little) / 65536.0;
    }

    int readInt32(int offset) {
      if (offset + 4 > raw.length) return 0;
      return view.getInt32(offset, Endian.little);
    }

    int readUint8(int offset) {
      if (offset >= raw.length) return 0;
      return view.getUint8(offset);
    }

    switch (type) {
      case Types.ObjectInfo:
        if (raw.length < 2) return ObjectInfo();
        return ObjectInfo(
          flags: FlagClass(raw[0]),
          runTiming: raw[1],
        );

      case Types.Bool:
        return readUint8(0) != 0;

      case Types.Function:
        return Functions.fromValue(readUint8(0));

      case Types.ObjectType:
        return ObjectTypes.fromValue(readUint8(0));

      case Types.Integer:
        return readInt32(0);

      case Types.Number:
        return toFixed(0);

      case Types.Vector2D:
        if (raw.length < 8) return Vector2D(0, 0);
        return Vector2D(toFixed(0), toFixed(4));

      case Types.Vector3D:
        if (raw.length < 12) return Vector3D(0, 0, 0);
        return Vector3D(toFixed(0), toFixed(4), toFixed(8));

      case Types.Coord2D:
        if (raw.length < 16) return Coord2D(Vector2D(0, 0), Vector2D(1, 0));
        return Coord2D(Vector2D(toFixed(0), toFixed(4)), Vector2D(toFixed(8), toFixed(12)));

      case Types.Coord3D:
        if (raw.length < 24) return Coord3D(Vector3D(0, 0, 0), Vector3D(0, 0, 0));
        return Coord3D(
            Vector3D(toFixed(0), toFixed(4), toFixed(8)),
            Vector3D(toFixed(12), toFixed(16), toFixed(20))
        );

      case Types.Text:
        try {
          int len = raw.length;
          while (len > 0 && raw[len - 1] == 0) len--;
          return utf8.decode(raw.sublist(0, len));
        } catch (e) { return "Encoding Error"; }

      case Types.Reference:
        return Reference.fromList(raw.toList());

      case Types.Colour:
        if (raw.length < 4) return Colour(0, 0, 0, 255);
        return Colour(raw[0], raw[1], raw[2], raw[3]);

      case Types.PortType:
        return readInt32(0);

      case Types.Pin:
      // Matches C++ struct Pin { uint8_t Number; char Port; }
        if (raw.length < 2) return 0; // Or return a custom Pin object
        return raw[0]; // Returning Number for now

      case Types.Board:
      case Types.Sensor:
      case Types.PortDriver:
      case Types.AccGyr:
      case Types.Geometry2D:
      case Types.GeometryOperation:
      case Types.Operation:
      case Types.Program:
      case Types.LocalFunction:
      case Types.Display:
      case Types.Byte:
      case Types.Type:
      case Types.Status:
      case Types.Input:
        return readUint8(0);

      default:
        return raw;
    }
  }
  @override
  String toString() {
    if (valueEntries.isEmpty) return "Empty Message";

    return valueEntries.map((entry) {
      String typeName = entry.type.toString().split('.').last;
      String pathStr = entry.path.pathString;
      dynamic data = entry.data;

      // 1. Format the data representation based on its actual type
      String dataStr;
      if (data is Functions) {
        dataStr = data.toString().split('.').last;
      } else if (data is ObjectTypes) {
        dataStr = data.toString().split('.').last;
      } else if (data is Reference) {
        // Use the fullAddress we built earlier (Net.Group.Device.Path)
        dataStr = "Ref(${data.fullAddress})";
      } else if (data.runtimeType.toString().contains('Text')) {
        // Handles your custom Text class safely
        dataStr = '"${data.Data}"';
      } else if (data is List<int>) {
        dataStr = "[${data.join(', ')}]";
      } else {
        dataStr = data.toString();
      }

      // 2. Include the Path in the output so you can see WHERE the data belongs
      return "{$pathStr} $typeName: $dataStr";
    }).join(" | ");
  }
}