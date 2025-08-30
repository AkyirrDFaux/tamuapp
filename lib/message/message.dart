import 'dart:typed_data';
import 'dart:convert';

import '../functions.dart';
import '../flags.dart';
import '../object/object.dart';
import '../types.dart';

class Message {
  List<Uint8List> segments; // Changed to a mutable List

  Message({List<Uint8List>? segments}) : segments = segments ?? []; // Initialize as a mutable list

  /// Creates a SegmentedMessage from a single Uint8List, splitting it into segments of the specified size.
  factory Message.fromBytes(Uint8List data) {
    final segments = <Uint8List>[];
    if (data.length < 4) {
      // Not enough data to read the message size
      return Message(segments: segments);
    }
    final byteData = ByteData.sublistView(data);
    final messageSize = byteData.getUint32(0,Endian.little);
    if (data.length < messageSize + 4) {
      // Not enough data to read the whole message
      return Message(segments: segments);
    }
    final messageData = data.sublist(4, messageSize + 4);
    int offset = 0;
    while (offset < messageData.length) {
      final segmentType = Types.fromValue(messageData[offset]);
      int segmentSize = Types.getSize(segmentType);
      if (segmentSize == -1) {
        switch (segmentType){
          case Types.Text:
            segmentSize = messageData[offset + 1] + 2;
          case Types.IDList:
            segmentSize = messageData[offset + 1]*4 + 2;
          default:
            segmentSize = 1;
        }

      }
      else{
        segmentSize += 1;
      }

      segments.add(messageData.sublist(offset, offset + segmentSize));
      offset += segmentSize;
    }
    return Message(segments: segments);
  }

  @override
  String toString() {
    String segmentStrings = segments.map((segment) {
      Types type = getSegmentType(segments.indexOf(segment));
      dynamic data = getSegmentData(segments.indexOf(segment));
      return "${type.name}: $data";
    }).join(", ");
    return segmentStrings;
  }

  /// Returns the number of segments in the message.
  int get segmentCount => segments.length;

  /// Adds a new segment to the end of the message.
  void addSegment(Types type, [dynamic data]) {
    Uint8List segment;
    if(Types.getSize(type) == -1){
      segment = Uint8List(2);
    }
    else{
      segment = Uint8List(Types.getSize(type) + 1);
    }
    segment[0] = type.value;
    segments.add(segment);

    if (data != null){
        setSegmentData(segments.length - 1, data);
      }
  }

  /// Returns the type of the segment based on the first byte.
  Types getSegmentType(int index) {
    if (index < 0 || index >= segments.length) {
      return Types.Undefined;
    }
    final segment = segments[index];
    if (segment.isEmpty) {
      return Types.Undefined;
    }
    return Types.fromValue(segment[0]);
  }

  /// Returns the data from the segment (excluding the type byte) as a dynamic value.
  dynamic getSegmentData(int index) {
    if (index < 0 || index >= segments.length) {
      throw RangeError.index(index, segments);
    }
    final segment = segments[index];
    if (segment.isEmpty) {
      return null;
    }
    final type = getSegmentType(index);
    switch (type) {
      case Types.Text:
        final textLength = segment[1];
        if (textLength == 0) {
          return null;
        }
        final data = segment.sublist(2, textLength + 2);
        return utf8.decode(data); // Decode as UTF-8 string
      case Types.Flags:
        final data = segment.sublist(1);
        return FlagClass(ByteData.sublistView(data).getUint8(0));
      case Types.Number:
        final data = segment.sublist(1);
        final byteData = ByteData.sublistView(data);
        return byteData.getFloat32(0,Endian.little); // Interpret as 32-bit float
      case Types.Integer:
        final data = segment.sublist(1);
        final byteData = ByteData.sublistView(data);
        return byteData.getInt32(0, Endian.little); // Interpret as 32-bit integer
      case Types.ID:
      case Types.Time:
        final data = segment.sublist(1);
        final byteData = ByteData.sublistView(data);
        return byteData.getUint32(0, Endian.little); // Interpret as unsigned 32-bit integer
      case Types.Vector2D:
        final data = segment.sublist(1);
        final byteData = ByteData.sublistView(data);
        return Vector2D(byteData.getFloat32(0, Endian.little),
            byteData.getFloat32(4, Endian.little));
      case Types.Coord2D:
          final data = segment.sublist(1);
          final byteData = ByteData.sublistView(data);
          return Coord2D(Vector2D(byteData.getFloat32(0, Endian.little),
                          byteData.getFloat32(4, Endian.little)),
                        Vector2D(byteData.getFloat32(8, Endian.little),
                          byteData.getFloat32(12, Endian.little)));
      case Types.Colour:
        final data = segment.sublist(1);
        final byteData = ByteData.sublistView(data);
        return Colour(byteData.getUint8(0), byteData.getUint8(1),
                byteData.getUint8(2), byteData.getUint8(3));
      case Types.IDList:
        final data = segment.sublist(2); // Skip type byte and length byte
        final byteData = ByteData.sublistView(data);
        final idList = <MapEntry<int, int>>[];
        int offset = 0;
        int index = 0;
        while (offset < data.length) {
          final value = byteData.getUint32(offset, Endian.little);
          idList.add(MapEntry(index, value));
          index += 1;
          offset += 4;
        }
        return idList;
      default:
        if (Types.getSize(type) == 1) {
          final data = segment.sublist(1);
          final byteData = ByteData.sublistView(data);
          switch (type){
            case Types.Type:
              return Types.fromValue(byteData.getUint8(0));
            case Types.Function:
              return Functions.fromValue(byteData.getUint8(0));
            default:
              return byteData.getUint8(0);
          }
        }
        else {
          return segment.sublist(1);
        }
    }
  }

  /// Sets the data of an existing segment.
  void setSegmentData(int index, dynamic data) {
    if (index < 0 || index >= segments.length) {
      throw RangeError.index(index, segments);
    }
    final type = getSegmentType(index);

    switch (type) {
      case Types.Text:
        if (data is String) {
          final encoded = utf8.encode(data);
          // Create a new segment with the correct size
          final newSegment = Uint8List(encoded.length + 2);
          newSegment[0] = type.value;
          newSegment[1] = encoded.length;
          newSegment.setRange(2, encoded.length + 2, encoded);
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be a String for Types.text");
        }
        break;
      case Types.Flags:
        if (data is FlagClass) {
          final segment = segments[index];
          ByteData.sublistView(segment).setUint8(1, data.value);
        } else {
          throw ArgumentError("Data must be a double for Types.float32");
        }
        break;
      case Types.Number:
        if (data is double) {
          final segment = segments[index];
          ByteData.sublistView(segment).setFloat32(1, data,Endian.little);
        } else {
          throw ArgumentError("Data must be a double for Types.float32");
        }
        break;
      case Types.Integer:
        if (data is int) {
          final segment = segments[index];
          ByteData.sublistView(segment).setInt32(1, data,Endian.little);
        } else {
          throw ArgumentError("Data must be an int for Types.int32");
        }
        break;
      case Types.ID:
      case Types.Time:
        if (data is int) {
          final segment = segments[index];
          ByteData.sublistView(segment).setUint32(1, data,Endian.little);
        } else {
          throw ArgumentError("Data must be an int for Time or ID");
        }
        break;
      case Types.Byte:
        if (data is int) {
          final segment = segments[index];
          segment[1] = data;
        } else {
          throw ArgumentError("Data must be an int for Types.byte");
        }
        break;
      case Types.Vector2D:
        if (data is Vector2D) {
          final segment = segments[index];
          ByteData.sublistView(segment).setFloat32(1, data.X,Endian.little);
          ByteData.sublistView(segment).setFloat32(5, data.Y,Endian.little);
        } else {
          throw ArgumentError("Data must be a Vector2D for Types.vector2D");
        }
        break;
        case Types.Coord2D:
          if (data is Coord2D){
            final segment = segments[index];
            ByteData.sublistView(segment).setFloat32(1, data.Position.X,Endian.little);
            ByteData.sublistView(segment).setFloat32(5, data.Position.Y,Endian.little);
            ByteData.sublistView(segment).setFloat32(9, data.Rotation.X,Endian.little);
            ByteData.sublistView(segment).setFloat32(13, data.Rotation.Y,Endian.little);
          }
          else{
            throw ArgumentError("Data must be a Coord2D for Types.coord2D");
          }
          break;
      case Types.Colour:
        if (data is Colour) {
          final segment = segments[index];
          ByteData.sublistView(segment).setUint8(1, data.R);
          ByteData.sublistView(segment).setUint8(2, data.G);
          ByteData.sublistView(segment).setUint8(3, data.B);
          ByteData.sublistView(segment).setUint8(4, data.A);
        } else {
          throw ArgumentError("Data must be a Uint8List of length 4 for Types.color");
        }
        break;
      case Types.Function:
      case Types.Type:
        if (data is Functions || data is Types) {
          final segment = segments[index];
          segment[1] = data.value;
        } else {
          throw ArgumentError("Data must be a Enum");
        }
        break;
      case Types.IDList:
        if (data is List<MapEntry<int, int>>) {
          final newSegment = Uint8List(data.length * 4+ 2);
          newSegment[0] = type.value;
          newSegment[1] = data.length;
          for (int i = 0; i < data.length; i++) {
            ByteData.sublistView(newSegment).setUint32(i * 4 + 2, data[i].value,Endian.little);
          }
          segments[index] = newSegment;
        }
        else{
            throw ArgumentError("Data must be a List<MapEntry<int, int>> for Types.IDList");
        }
        break;
      default:
        if (data is int && Types.getSize(type) == 1) {
          final segment = segments[index];
          ByteData.sublistView(segment).setUint8(1, data);
        }
        else {
          throw ArgumentError("Unsupported segment type for setting data.");
        }
    }
  }

  void removeSegment(int index) {
    segments.removeAt(index);
  }
}