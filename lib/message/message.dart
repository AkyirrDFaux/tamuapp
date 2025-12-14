import 'dart:typed_data';
import 'dart:convert';

import '../values.dart';
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
    final messageSize = byteData.getUint32(0, Endian.little);
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
        // Handle variable-length segments
        switch (segmentType) {
          case Types.Text:
          // Ensure there's enough data for the length byte
            if (offset + 1 < messageData.length) {
              segmentSize = messageData[offset + 1] + 2; // type + length + data
            } else {
              segmentSize = 1; // Malformed, treat as single byte
            }
            break; // <-- FIX: Added break
          case Types.IDList:
          // Ensure there's enough data for the length byte
            if (offset + 1 < messageData.length) {
              segmentSize = messageData[offset + 1] * 4 + 2; // type + length + data
            } else {
              segmentSize = 1; // Malformed, treat as single byte
            }
            break; // <-- FIX: Added break
          default:
          // Should not happen if getSize is defined for all var-length types
            segmentSize = 1;
            break;
        }
      } else {
        // Fixed-length segments (including data-less ones like Undefined)
        segmentSize += 1; // Add 1 for the type byte
      }

      // Final safety check to prevent overflow
      if (offset + segmentSize > messageData.length) {
        // The declared size is larger than the available data, indicates a corrupt message.
        // Add the rest of the data as the last, possibly corrupt, segment.
        segmentSize = messageData.length - offset;
      }

      segments.add(messageData.sublist(offset, offset + segmentSize));
      offset += segmentSize;
    }
    return Message(segments: segments);
  }

  @override
  String toString() {
    if (segments.isEmpty) {
      return "Message (empty)";
    }
    // Use map to create a list of strings, each representing a segment,
    // then join them with a newline character.
    String segmentStrings = segments.map((segment) {
      // It's safer to get the index directly rather than relying on segments.indexOf(segment)
      // if segments could potentially contain duplicate Uint8List instances (though unlikely here).
      // However, for simplicity and assuming unique segments in the list order:
      int index = segments.indexOf(segment); // Be cautious if segments can have identical Uint8List instances
      if (index == -1) return "Error: Segment not found in message"; // Should not happen with current structure

      Types type = getSegmentType(index);
      dynamic data;
      try {
        data = getSegmentData(index);
      } catch (e) {
        data = "Error reading data: $e";
      }

      if (isInValueEnum(type)){
        return "  ${type.name}: ${getValueEnum(type, data)}"; // Added indentation for better readability
      }
      return "  ${type.name}: $data"; // Added indentation for better readability
    }).join("\n"); // Join with newline character

    return "\n$segmentStrings"; // Add a header for the message itself
  }

  /// Returns the number of segments in the message.
  int get segmentCount => segments.length;

  /// Adds a new segment to the end of the message.
  void addSegment(Types type, [dynamic data]) {
    // Determine if the type is one that should not have data.
    bool isDataLessType = (Types.getSize(type) == 0);

    if (data != null && !isDataLessType) {
      // Data is provided and the type supports data.
      // Create a placeholder segment; it will be replaced by setSegmentData.
      segments.add(Uint8List(0));
      setSegmentData(segments.length - 1, data, type: type);
    } else {
      // No data is provided, or the type is inherently data-less (e.g., EOL, Undefined).
      // Create a simple segment with only the type byte.
      final segment = Uint8List(1);
      segment[0] = type.value;
      segments.add(segment);
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
    if (segment.length <= 1) { // Changed to <= 1 to handle data-less segments
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
      case Types.Vector3D:
        final data = segment.sublist(1);
        final byteData = ByteData.sublistView(data);
        return Vector3D(byteData.getFloat32(0, Endian.little),
            byteData.getFloat32(4, Endian.little),byteData.getFloat32(8, Endian.little));
      case Types.Coord2D:
        final data = segment.sublist(1);
        final byteData = ByteData.sublistView(data);
        return Coord2D(Vector2D(byteData.getFloat32(0, Endian.little),
            byteData.getFloat32(4, Endian.little)),
            Vector2D(byteData.getFloat32(8, Endian.little),
                byteData.getFloat32(12, Endian.little)));
      case Types.Coord3D:
        final data = segment.sublist(1);
        final byteData = ByteData.sublistView(data);
        return Coord3D(
          Vector3D(byteData.getFloat32(0, Endian.little), byteData.getFloat32(4, Endian.little), byteData.getFloat32(8, Endian.little)),
          Vector3D(byteData.getFloat32(12, Endian.little), byteData.getFloat32(16, Endian.little), byteData.getFloat32(20, Endian.little)),
        );
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
            case Types.ObjectType:
              return ObjectTypes.fromValue(byteData.getUint8(0));
            case Types.Function:
              return Functions.fromValue(byteData.getUint8(0));
            case Types.Bool:
              return byteData.getUint8(0) == 1;
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
  void setSegmentData(int index, dynamic data, {Types? type}) {
    if (index < 0 || index >= segments.length) {
      throw RangeError.index(index, segments);
    }
    final segmentType = type ?? getSegmentType(index);

    switch (segmentType) {
      case Types.Text:
        if (data is String) {
          final encoded = utf8.encode(data);
          // Create a new segment with the correct size
          final newSegment = Uint8List(encoded.length + 2);
          newSegment[0] = segmentType.value;
          newSegment[1] = encoded.length;
          newSegment.setRange(2, encoded.length + 2, encoded);
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be a String for Types.text");
        }
        break;
      case Types.Flags:
        if (data is FlagClass) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          ByteData.sublistView(newSegment).setUint8(1, data.value);
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be a FlagClass for Types.Flags");
        }
        break;
      case Types.Number:
        if (data is double) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          ByteData.sublistView(newSegment).setFloat32(1, data,Endian.little);
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be a double for Types.float32");
        }
        break;
      case Types.Integer:
        if (data is int) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          ByteData.sublistView(newSegment).setInt32(1, data,Endian.little);
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be an int for Types.int32");
        }
        break;
      case Types.ID:
      case Types.Time:
        if (data is int) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          ByteData.sublistView(newSegment).setUint32(1, data,Endian.little);
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be an int for Time or ID");
        }
        break;
      case Types.Byte:
        if (data is int) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          newSegment[1] = data;
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be an int for Types.byte");
        }
        break;
      case Types.Bool:
        if (data is bool) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          newSegment[1] = data ? 1 : 0;
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be a bool for Types.Bool");
        }
        break;
      case Types.Vector2D:
        if (data is Vector2D) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          ByteData.sublistView(newSegment).setFloat32(1, data.X,Endian.little);
          ByteData.sublistView(newSegment).setFloat32(5, data.Y,Endian.little);
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be a Vector2D for Types.vector2D");
        }
        break;
      case Types.Vector3D:
        if (data is Vector3D) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          ByteData.sublistView(newSegment).setFloat32(1, data.X,Endian.little);
          ByteData.sublistView(newSegment).setFloat32(5, data.Y,Endian.little);
          ByteData.sublistView(newSegment).setFloat32(9, data.Z,Endian.little);
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be a Vector3D for Types.vector2D");
        }
        break;
      case Types.Coord2D:
        if (data is Coord2D){
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          ByteData.sublistView(newSegment).setFloat32(1, data.Position.X,Endian.little);
          ByteData.sublistView(newSegment).setFloat32(5, data.Position.Y,Endian.little);
          ByteData.sublistView(newSegment).setFloat32(9, data.Rotation.X,Endian.little);
          ByteData.sublistView(newSegment).setFloat32(13, data.Rotation.Y,Endian.little);
          segments[index] = newSegment;
        }
        else{
          throw ArgumentError("Data must be a Coord2D for Types.coord2D");
        }
        break;
      case Types.Coord3D:
        if (data is Coord3D) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          final byteData = ByteData.sublistView(newSegment, 1);
          byteData.setFloat32(0, data.Position.X, Endian.little);
          byteData.setFloat32(4, data.Position.Y, Endian.little);
          byteData.setFloat32(8, data.Position.Z, Endian.little);
          byteData.setFloat32(12, data.Rotation.X, Endian.little);
          byteData.setFloat32(16, data.Rotation.Y, Endian.little);
          byteData.setFloat32(20, data.Rotation.Z, Endian.little);
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be a Coord3D for Types.coord3D");
        }
        break;
      case Types.Colour:
        if (data is Colour) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          ByteData.sublistView(newSegment).setUint8(1, data.R);
          ByteData.sublistView(newSegment).setUint8(2, data.G);
          ByteData.sublistView(newSegment).setUint8(3, data.B);
          ByteData.sublistView(newSegment).setUint8(4, data.A);
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be a Uint8List of length 4 for Types.color");
        }
        break;
      case Types.Function:
        if (data is Functions) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          newSegment[1] = data.value;
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be a Function");
        }
        break;
      case Types.ObjectType:
        if (data is ObjectTypes) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          newSegment[1] = data.value;
          segments[index] = newSegment;
        } else {
          throw ArgumentError("Data must be an ObjectType");
        }
        break;
      case Types.IDList:
        if (data is List<MapEntry<int, int>>) {
          final newSegment = Uint8List(data.length * 4+ 2);
          newSegment[0] = segmentType.value;
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
        if (data is int && Types.getSize(segmentType) == 1) {
          final newSegment = Uint8List(Types.getSize(segmentType) + 1);
          newSegment[0] = segmentType.value;
          ByteData.sublistView(newSegment).setUint8(1, data);
          segments[index] = newSegment;
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
