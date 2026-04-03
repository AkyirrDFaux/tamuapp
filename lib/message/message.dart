import 'dart:typed_data';
import 'dart:convert';

import '../functions.dart';
import '../info.dart';
import '../object/object.dart';
import '../types.dart';

dynamic deserializeData(Types type, Uint8List raw) {
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

  int readUint32(int offset) {
    if (offset + 4 > raw.length) return 0;
    return view.getUint32(offset, Endian.little);
  }

  int readUint8(int offset) {
    if (offset >= raw.length) return 0;
    return view.getUint8(offset);
  }

  int readInt8(int offset) {
    if (offset >= raw.length) return 0;
    return view.getInt8(offset);
  }

  switch (type) {
    case Types.PortNumber:
      return readInt8(0);

    case Types.ObjectInfo:
      if (raw.length < 2) return ObjectInfo();
      return ObjectInfo(
        flags: FlagClass(raw[0]),
        runPeriod: raw[1],
        runPhase: raw[2],
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
      return Coord2D(
        Vector2D(toFixed(0), toFixed(4)),
        Vector2D(toFixed(8), toFixed(12)),
      );

    case Types.Coord3D:
      if (raw.length < 24) return Coord3D(Vector3D(0, 0, 0), Vector3D(0, 0, 0));
      return Coord3D(
        Vector3D(toFixed(0), toFixed(4), toFixed(8)),
        Vector3D(toFixed(12), toFixed(16), toFixed(20)),
      );

    case Types.Text:
      try {
        int len = raw.length;
        while (len > 0 && raw[len - 1] == 0) len--;
        return utf8.decode(raw.sublist(0, len));
      } catch (e) {
        return "Encoding Error";
      }

    case Types.Reference:
      return Reference.fromBytes(raw);

    case Types.Colour:
      if (raw.length < 4) return Colour(0, 0, 0, 255);
      return Colour(raw[0], raw[1], raw[2], raw[3]);

    case Types.PortType:
      return readUint32(0);

    case Types.Pin:
      // Matches C++ struct Pin { uint8_t Number; char Port; }
      if (raw.length < 2) return 0; // Or return a custom Pin object
      return raw[0]; // Returning Number for now

    case Types.Board:
    case Types.Sensor:
    case Types.PortDriver:
    case Types.I2CDevice:
    case Types.Geometry2D:
    case Types.GeometryOperation:
    case Types.Operation:
    case Types.Program:
    case Types.Outputs:
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

Uint8List serializeData(Types type, dynamic data) {
  if (data == null) return Uint8List(0);

  void packFixed(ByteData view, int offset, dynamic val) {
    int fixedVal = ((val as num).toDouble() * 65536.0).round();
    view.setInt32(offset, fixedVal, Endian.little);
  }

  void packInt32(ByteData view, int offset, int val) {
    view.setInt32(offset, val, Endian.little);
  }

  void packUint32(ByteData view, int offset, int val) {
    view.setUint32(offset, val, Endian.little);
  }

  switch (type) {
    case Types.ObjectInfo:
      if (data is ObjectInfo) {
        // [FlagByte, TimingByte]
        return Uint8List.fromList([
          data.flags.value & 0xFF,
          data.runPeriod & 0xFF,
          data.runPhase & 0xFF,
        ]);
      }
      return Uint8List(2);

    case Types.PortNumber:
      // C++ int8_t: Ensure value is within -128 to 127
      int val = (data is int) ? data : 0;
      return Uint8List.fromList([val.toSigned(8) & 0xFF]);

    case Types.Bool:
      return Uint8List.fromList([(data == true || data == 1) ? 1 : 0]);

    case Types.Function:
      int val = (data is Functions) ? data.value : (data as int);
      return Uint8List.fromList([val & 0xFF]);

    case Types.ObjectType:
      int val = (data is ObjectTypes) ? data.value : (data as int);
      return Uint8List.fromList([val & 0xFF]);

    case Types.Integer:
      final b = Uint8List(4);
      packInt32(ByteData.view(b.buffer), 0, data as int);
      return b;
    case Types.PortType:
      final b = Uint8List(4);
      packUint32(ByteData.view(b.buffer), 0, data as int);
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
      if (data is Reference) {
        // ALIGNMENT: Use the proportional toBytes() which is PathLen + 4
        return Uint8List.fromList(data.toBytes());
      }
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
    case Types.I2CDevice:
    case Types.Geometry2D:
    case Types.GeometryOperation:
    case Types.Operation:
    case Types.Program:
    case Types.Outputs:
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
