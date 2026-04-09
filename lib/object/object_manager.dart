import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../info.dart';
import '../message/message.dart';
import '../message/message_queue.dart';
import '../values.dart';
import 'object.dart';
import '../types.dart';
import '../functions.dart';
import 'dart:collection';

class ObjectManager extends ChangeNotifier {
  static final ObjectManager _instance = ObjectManager._internal();
  factory ObjectManager() => _instance;
  ObjectManager._internal();

  /// Key: fullAddress (String) e.g., "0.0.1"
  final Map<String, NodeObject> _objects = {};

  UnmodifiableListView<NodeObject> get objects => UnmodifiableListView(_objects.values);

  void registerObject(NodeObject obj) {
    _objects[obj.id.globalAddress] = obj;
    notifyListeners();
  }

  NodeObject? getObjectByRef(Reference ref) {
    return _objects[ref.globalAddress];
  }

  /// Update a value via global Reference (updates the specific path within that reference)
  /// Update a value via global Reference (preserves existing flags)
  void updateObjectValue(Reference targetRef, Types type, dynamic data) {
    final obj = getObjectByRef(targetRef);
    if (obj != null) {
      // Look up existing flags for this path string
      final existing = obj.values[targetRef.location.pathString];

      obj.updateValue(
        targetRef.location,
        type,
        data,
        isReadOnly: existing?.isReadOnly ?? false,
        isSetupCall: existing?.isSetupCall ?? false,
      );
      notifyListeners();
    }
  }

  /// Clears the local registry and asks the MCU to stream all current objects
  void reloadObjects() {
    _objects.clear();

    // 1. Prepare 1-byte payload: [Func:1]
    final Uint8List payload = Uint8List(1);
    payload[0] = Functions.Refresh.value;

    // 2. Log to Inspector
    MessageQueue().addSegments(
        [QueueSegment(Types.Function, Functions.Refresh)],
        MessageDirection.output,
        raw: payload
    );

    // 3. Send to MCU
    BluetoothManager().sendMessage(payload);

    notifyListeners();
  }

  /// Clears the local registry and asks the MCU to stream all current objects
  void format() {

    // 1. Prepare 1-byte payload: [Func:1]
    final Uint8List payload = Uint8List(1);
    payload[0] = Functions.Format.value;

    // 2. Log to Inspector
    MessageQueue().addSegments(
        [QueueSegment(Types.Function, Functions.Refresh)],
        MessageDirection.output,
        raw: payload
    );

    // 3. Send to MCU
    BluetoothManager().sendMessage(payload);
  }

  /// Requests the full state of a specific object
  void refreshObject(Reference ref) {
    // 1. Prepare 4-byte payload: [Func:1][Net:1][Group:1][Dev:1]
    final Uint8List payload = Uint8List(4);
    payload[0] = Functions.ReadObject.value;
    payload[1] = ref.net;
    payload[2] = ref.group;
    payload[3] = ref.device;

    // 2. Log to Inspector
    MessageQueue().addSegments([
      QueueSegment(Types.Function, Functions.ReadObject),
      QueueSegment(Types.Reference, ref),
    ], MessageDirection.output, raw: payload);

    // 3. Send raw bytes
    BluetoothManager().sendMessage(payload);
  }

  void createObject(Reference ref, ObjectTypes type) {
    // 1. Prepare 5-byte payload: [Func:1][Net:1][Group:1][Dev:1][Type:1]
    final Uint8List payload = Uint8List(5);

    payload[0] = Functions.CreateObject.value;
    payload[1] = ref.net;
    payload[2] = ref.group;
    payload[3] = ref.device;
    payload[4] = type.value;

    // 2. Log to Inspector
    MessageQueue().addSegments([
      QueueSegment(Types.Function, Functions.CreateObject),
      QueueSegment(Types.Reference, ref),
      QueueSegment(Types.ObjectType, type),
    ], MessageDirection.output, raw: payload);

    // 3. Send raw bytes
    BluetoothManager().sendMessage(payload);
  }

  void onCreateObjectResponse(Uint8List payload) {
    // 1. Validation: Expecting [Type][Net][Group][Dev] = 4 bytes
    // (The Function byte [0] is already stripped by the router)
    if (payload.length < 4) return;

    // 2. Extract Type (Offset 0) and Reference (Offsets 1, 2, 3)
    final ObjectTypes objType = ObjectTypes.fromValue(payload[0]);

    final Reference objRef = Reference.fromNetGroupDevice(
        payload[1],
        payload[2],
        payload[3]
    );

    // 3. Register a placeholder object
    // This ensures the UI updates immediately with the correct Type/ID
    if (!_objects.containsKey(objRef.fullAddress)) {
      final newObj = NodeObject(type: objType, id: objRef);
      registerObject(newObj);

      // 4. Follow up with a refresh to fetch Name, Flags, and Tree Values
      // Since the initial Create only returns the basics.
      refreshObject(objRef);
    }

    // 5. Log to Inspector
    MessageQueue().addSegments([
      QueueSegment(Types.Function, Functions.CreateObject),
      QueueSegment(Types.ObjectType, objType),
      QueueSegment(Types.Reference, objRef),
    ], MessageDirection.input, raw: payload);

    notifyListeners();
  }

  void deleteObject(Reference ref) {
    // 1. Prepare 4-byte payload: [Func:1][Net:1][Group:1][Dev:1]
    final Uint8List payload = Uint8List(4);

    payload[0] = Functions.DeleteObject.value;
    payload[1] = ref.net;
    payload[2] = ref.group;
    payload[3] = ref.device;

    // 2. Log to Inspector
    MessageQueue().addSegments([
      QueueSegment(Types.Function, Functions.DeleteObject),
      QueueSegment(Types.Reference, ref),
    ], MessageDirection.output, raw: payload);

    // 3. Send raw bytes
    BluetoothManager().sendMessage(payload);
  }

  void onDeleteObjectResponse(Uint8List payload) {
    // 1. Validation: Expecting 3 bytes for [Net][Group][Dev]
    if (payload.length < 3) return;

    // 2. Map the 3-byte ID to a Reference
    final Reference objRef = Reference.fromNetGroupDevice(
        payload[0],
        payload[1],
        payload[2]
    );

    // 3. Remove from local state
    // Using the cached fullAddress string as the key
    if (_objects.containsKey(objRef.fullAddress)) {
      _objects.remove(objRef.fullAddress);
      print("DELETED: Object ${objRef.fullAddress} removed from registry.");
    }

    // 4. Log to Inspector
    MessageQueue().addSegments([
      QueueSegment(Types.Function, Functions.DeleteObject),
      QueueSegment(Types.Reference, objRef),
      QueueSegment(Types.Status, "Destroyed"),
    ], MessageDirection.input, raw: payload);

    notifyListeners();
  }

  void saveAll() {
    // 1. Prepare a 1-byte payload: [Func:1]
    final Uint8List payload = Uint8List(1);
    payload[0] = Functions.SaveAll.value;

    // 2. Log to Inspector
    MessageQueue().addSegments(
        [QueueSegment(Types.Function, Functions.SaveAll)],
        MessageDirection.output,
        raw: payload
    );

    // 3. Send to BluetoothManager
    // BluetoothManager will wrap this into [Length:03 00][Func:XX]
    BluetoothManager().sendMessage(payload);
  }

  void saveObject(Reference ref) {
    // 1. Prepare 4-byte payload: [Func:1][Net:1][Group:1][Dev:1]
    final Uint8List payload = Uint8List(4);

    payload[0] = Functions.SaveObject.value;
    payload[1] = ref.net;
    payload[2] = ref.group;
    payload[3] = ref.device;

    // 2. Log to Inspector
    MessageQueue().addSegments([
      QueueSegment(Types.Function, Functions.SaveObject),
      QueueSegment(Types.Reference, ref),
    ], MessageDirection.output, raw: payload);

    // 3. Send raw bytes
    BluetoothManager().sendMessage(payload);
  }

  void onSaveObjectResponse(Uint8List payload) {
    // 1. Validation: Expecting 3 bytes for [Net][Group][Dev]
    // (Function byte already stripped by runMessage)
    if (payload.length < 3) return;

    // 2. Map the 3-byte ID back to a Reference object
    final Reference objRef = Reference.fromNetGroupDevice(
        payload[0],
        payload[1],
        payload[2]
    );

    // 3. Update local state
    final targetObject = getObjectByRef(objRef);
    if (targetObject != null) {
      // Clear any "unsaved" UI indicators here
      print("MCU confirmed Save for: ${objRef.fullAddress}");
    }

    // 4. Log to Inspector
    MessageQueue().addSegments([
      QueueSegment(Types.Function, Functions.SaveObject),
      QueueSegment(Types.Reference, objRef),
      QueueSegment(Types.Status, "Flash Write OK"),
    ], MessageDirection.input, raw: payload);

    notifyListeners();
  }

  void onReadObjectResponse(Uint8List payload) {
    int offset = 0;
    final bd = ByteData.view(payload.buffer, payload.offsetInBytes, payload.length);

    try {
      // 1. Identity (3 bytes)
      final ref = Reference.fromNetGroupDevice(payload[offset], payload[offset + 1], payload[offset + 2]);
      offset += 3;

      // 2. Metadata (4 bytes)
      final objType = ObjectTypes.fromValue(payload[offset++]);
      final target = getObjectByRef(ref) ?? NodeObject(type: objType, id: ref);

      target.values.clear();

      target.info.flags.value = payload[offset++];
      target.info.runPeriod = payload[offset++];
      target.info.runPhase = payload[offset++];

      // 3. Name (Pascal String)
      final int nameLen = payload[offset++];
      if (nameLen > 0) {
        target.name = utf8.decode(payload.sublist(offset, offset + nameLen));
        offset += nameLen;
      }

      // 4. ValueTree Header
      if (offset + 4 > payload.length) return;
      final int vtTotalSize = bd.getUint16(offset, Endian.little);
      final int hCount = bd.getUint16(offset + 2, Endian.little);
      offset += 4;

      // Prepare segments for the Message Inspector
      List<QueueSegment> logSegments = [
        QueueSegment(Types.Function, Functions.ReadObject),
        QueueSegment(Types.Reference, ref),
        QueueSegment(Types.ObjectType, objType),
        QueueSegment(Types.Text, target.name),
      ];

      // 5. ValueTree Traversal Logic
      int hStart = offset;
      int dStart = hStart + (hCount * 4);
      int currentDataPtr = dStart;

      List<int> pathCounters = [];
      List<int> currentPath = [];

      for (int i = 0; i < hCount; i++) {
        int hPos = hStart + (i * 4);
        final int typeVal = payload[hPos];

        // --- NEW: Flag Extraction ---
        final int rawDepthByte = payload[hPos + 1];
        final bool isSetupCall = (rawDepthByte & 0x80) != 0; // Bit 7
        final bool isReadOnly  = (rawDepthByte & 0x40) != 0; // Bit 6
        final int depth = rawDepthByte & 0x3F;             // Bits 0-5
        // ----------------------------

        final int dataLen = bd.getUint16(hPos + 2, Endian.little);

        // Path/Depth Adjustment
        if (depth < currentPath.length) {
          currentPath = currentPath.sublist(0, depth);
          if (pathCounters.length > depth + 1) {
            pathCounters = pathCounters.sublist(0, depth + 1);
          }
        }

        while (pathCounters.length <= depth) {
          pathCounters.add(-1);
        }

        pathCounters[depth]++;

        if (currentPath.length <= depth) {
          currentPath.add(pathCounters[depth]);
        } else {
          currentPath[depth] = pathCounters[depth];
        }

        // Reset children counters
        if (pathCounters.length > depth + 1) {
          for (int j = depth + 1; j < pathCounters.length; j++) pathCounters[j] = -1;
        }

        final Path nodePath = Path(List.from(currentPath));
        final Types dataType = Types.fromValue(typeVal);
        dynamic decodedValue;

        // Data Extraction
        if (dataLen > 0 && currentDataPtr + dataLen <= payload.length) {
          final rawVal = payload.sublist(currentDataPtr, currentDataPtr + dataLen);
          decodedValue = deserializeData(dataType, rawVal);
          currentDataPtr += dataLen;
        }

        // --- UPDATED: Apply to Object Model with Flags ---
        target.updateValue(
            nodePath,
            dataType,
            decodedValue,
            isReadOnly: isReadOnly,
            isSetupCall: isSetupCall
        );

        // Add to Logger with metadata hints
        String flagNote = "";
        if (isReadOnly) flagNote += "[RO]";
        if (isSetupCall) flagNote += "[Setup]";

        logSegments.add(QueueSegment(
            dataType,
            "${decodedValue ?? 'Folder'} $flagNote",
            depth: depth + 1
        ));
      }

      // Commit to Inspector
      MessageQueue().addSegments(logSegments, MessageDirection.input, raw: payload);

      registerObject(target);
      notifyListeners();

    } catch (e) {
      print("ReadObject Parse Error: $e");
      MessageQueue().addSegments([
        QueueSegment(Types.Function, Functions.ReadObject),
        QueueSegment(Types.Status, "Parse Error"),
        QueueSegment(Types.Text, e.toString()),
      ], MessageDirection.input, raw: payload);
    }
  }

  /// [0]Func, [1]Ref, [2+]Values
  void readValue(Uint8List payload) {
    if (payload.length < 5) return;

    final Reference objRef = Reference.fromBytes(payload);
    final int idSize = 4 + objRef.location.length;
    final int payloadOffset = idSize;

    if (payload.length < payloadOffset + 3) return;
    final int typeByte = payload[payloadOffset];
    final Types dataType = Types.fromValue(typeByte);

    final ByteData bd = ByteData.view(payload.buffer, payload.offsetInBytes, payload.length);
    final int dataLen = bd.getUint16(payloadOffset + 1, Endian.little);

    final int dataStart = payloadOffset + 3;
    if (payload.length < dataStart + dataLen) return;
    final Uint8List rawData = payload.sublist(dataStart, dataStart + dataLen);

    final targetObject = getObjectByRef(objRef);
    if (targetObject != null) {
      final dynamic parsedData = deserializeData(dataType, rawData);

      // --- FIX: Preserve Flags ---
      // Look up the existing entry for this specific path
      final existingEntry = targetObject.values[objRef.location.pathString];

      // If it exists, grab its current flags. Otherwise, default to false.
      bool currentRO = existingEntry?.isReadOnly ?? false;
      bool currentSetup = existingEntry?.isSetupCall ?? false;

      // Update the value while keeping the old flags intact
      targetObject.updateValue(
        objRef.location,
        dataType,
        parsedData,
        isReadOnly: currentRO,
        isSetupCall: currentSetup,
      );
      // ---------------------------

      MessageQueue().addSegments([
        QueueSegment(Types.Function, Functions.ReadValue),
        QueueSegment(Types.Reference, objRef),
        QueueSegment(dataType, parsedData),
      ], MessageDirection.input, raw: payload);

      notifyListeners();
    }
  }

  void writeValue(Reference ref, dynamic value, {required Types type}) {
    // 1. Serialize the value to bytes based on its type
    final Uint8List dataBytes = serializeData(type, value);

    // 2. Determine sizes
    // ref.toBytes() should return [Net, Group, Dev, PathLen, ...PathIndices]
    final Uint8List refBytes = ref.toBytes();
    final int totalPayloadSize = 1 + refBytes.length + 1 + 2 + dataBytes.length;

    // 3. Build the packed buffer
    final Uint8List payload = Uint8List(totalPayloadSize);
    final ByteData bd = ByteData.view(payload.buffer);

    int offset = 0;

    // [Byte 0] Function Code
    payload[offset++] = Functions.WriteValue.value;

    // [Bytes 1...] Reference (Variable length)
    payload.setRange(offset, offset + refBytes.length, refBytes);
    offset += refBytes.length;

    // [Offset] Payload Type (1 byte)
    payload[offset++] = type.value;

    // [Offset + 1] Payload Length (2 bytes, Little Endian)
    bd.setUint16(offset, dataBytes.length, Endian.little);
    offset += 2;

    // [Offset + 3...] Actual Data
    payload.setRange(offset, offset + dataBytes.length, dataBytes);

    // 4. Update the Message Inspector
    MessageQueue().addSegments([
      QueueSegment(Types.Function, Functions.WriteValue),
      QueueSegment(Types.Reference, ref),
      QueueSegment(type, value),
    ], MessageDirection.output, raw: payload);

    // 5. Send to MCU
    BluetoothManager().sendMessage(payload);
  }

  void deleteValue(Reference ref) {
    // 1. Serialize the reference
    // ref.toBytes() returns [Net, Group, Dev, PathLen, ...PathIndices]
    final Uint8List refBytes = ref.toBytes();

    // 2. Total size: 1 byte (Function Code) + Variable length (Reference)
    final int totalPayloadSize = 1 + refBytes.length;

    // 3. Build the packed buffer
    final Uint8List payload = Uint8List(totalPayloadSize);

    int offset = 0;

    // [Byte 0] Function Code
    payload[offset++] = Functions.WriteValue.value;

    // [Bytes 1...] Reference
    payload.setRange(offset, offset + refBytes.length, refBytes);

    // 4. Update the Message Inspector
    // We omit the value/type segments since there is no payload
    MessageQueue().addSegments([
      QueueSegment(Types.Function, Functions.WriteValue),
      QueueSegment(Types.Reference, ref),
    ], MessageDirection.output, raw: payload);

    // 5. Send to MCU
    BluetoothManager().sendMessage(payload);
  }

  void onReadInfoResponse(Uint8List payload) {
    // 1. Validation: Payload must be exactly 7 bytes (1 Func + 3 Ref + 3 Info)
    if (payload.length < 6) return;

    // 2. Extract Reference from Bytes [1, 2, 3]
    // Matching C++: Reference::Global(Input.Array[1], Input.Array[2], Input.Array[3])
    final Reference objRef = Reference(
        payload[0],
        payload[1],
        payload[2]
    );
    print("Getting ref ReadInfo for ${objRef}");
    // 3. Resolve the local object
    final targetObject = getObjectByRef(objRef);
    if (targetObject == null) return;
    print("Got obj ReadInfo for ${objRef}");
    // 4. Extract ObjectInfo from Bytes [4, 5, 6]
    // Byte 4: Flags, Byte 5: RunPeriod, Byte 6: RunPhase
    final int rawFlags = payload[3];
    final int newPeriod = payload[4];
    final int newPhase = payload[5];

    // 5. Update local state
    targetObject.info.flags.value = rawFlags;
    targetObject.info.runPeriod = newPeriod;
    targetObject.info.runPhase = newPhase;

    // 6. Log to MessageQueue for the Inspector
    // This recreates the "Human Readable" segments from the raw bytes
    MessageQueue().addSegments(
      [
        QueueSegment(Types.Function, Functions.ReadInfo),
        QueueSegment(Types.Reference, objRef),
        QueueSegment(Types.ObjectInfo, targetObject.info),
      ],
      MessageDirection.input,
      raw: payload,
    );
    print("Notifying ReadInfo for ${objRef}");
    notifyListeners();
  }

  void writeInfo(Reference ref, ObjectInfo info) {
    // 1. Prepare the 7-byte raw payload for the MCU
    // [Func][Net][Group][Dev][Flags][Period][Phase]
    final Uint8List payload = Uint8List(7);

    payload[0] = Functions.SetInfo.value;
    payload[1] = ref.net;
    payload[2] = ref.group;
    payload[3] = ref.device;
    payload[4] = info.flags.value;
    payload[5] = info.runPeriod;
    payload[6] = info.runPhase;

    // 2. Add to the MessageQueue using the new Segmented structure
    // This is what the ChatBubble will iterate over to display text
    MessageQueue().addSegments(
        [
          QueueSegment(Types.Function, Functions.SetInfo),
          QueueSegment(Types.Reference, ref),
          QueueSegment(Types.ObjectInfo, info),
        ],
        MessageDirection.output,
        raw: payload // Attach the raw bytes so long-press shows the hex!
    );

    // 3. Ship it to the BluetoothManager
    // Remember: BluetoothManager will prepend the 2-byte length [07 00]
    BluetoothManager().sendMessage(payload);
  }

  void handleReport(Uint8List payload) {
    // 1. Validation: Need at least 1 byte for the Status index
    if (payload.length < 1) return;

    // 2. Parse the Status String using your new lookup map
    final int statusIndex = payload[0];
    final String statusName = getValueEnum(Types.Status, statusIndex) ?? "Unknown ($statusIndex)";

    // 4. Update the Inspector
    // This turns raw bytes into: [Report] [Status: InvalidID]
    MessageQueue().addSegments([
      QueueSegment(Types.Function, Functions.Report),
      QueueSegment(Types.Status, statusName),
    ], MessageDirection.input, raw: payload);

    notifyListeners();
  }

  void writeName(Reference ref, String name) {
    // 1. Convert string to UTF-8 bytes
    final Uint8List nameBytes = Uint8List.fromList(utf8.encode(name));

    // 2. Prepare payload: [Func(1)][Ref(3)][Len(1)][Name(N)]
    final Uint8List payload = Uint8List(5 + nameBytes.length);

    payload[0] = Functions.WriteName.value; // Ensure Functions.WriteName exists in your enum
    payload[1] = ref.net;
    payload[2] = ref.group;
    payload[3] = ref.device;
    payload[4] = nameBytes.length; // Length byte matches Input.Array[4] in C++

    // Copy name bytes into payload starting at index 5
    payload.setRange(5, 5 + nameBytes.length, nameBytes);

    // 3. Log to MessageQueue
    MessageQueue().addSegments(
        [
          QueueSegment(Types.Function, Functions.WriteName),
          QueueSegment(Types.Reference, ref),
          QueueSegment(Types.Text, name),
        ],
        MessageDirection.output,
        raw: payload
    );

    // 4. Send to MCU
    BluetoothManager().sendMessage(payload);
  }

  void onReadNameResponse(Uint8List payload) {
    // 1. Validation: Min 4 bytes [Net][Group][Dev][Len]
    if (payload.length < 4) return;

    // 2. Parse Reference
    final ref = Reference(payload[0], payload[1], payload[2], Path([]));

    // 3. Parse Name Length and String
    final int nameLen = payload[3];

    // Safety check to ensure we don't read past the buffer
    if (4 + nameLen > payload.length) return;

    final String name = utf8.decode(payload.sublist(4, 4 + nameLen -1));

    // 4. Update the ObjectManager's local state
    final object = getObjectByRef(ref);
    if (object != null) {
      // Assuming NodeObject has a name setter or you notify listeners
      object.name = name;
    }

    // 5. Log to MessageQueue
    MessageQueue().addSegments(
        [
          QueueSegment(Types.Function, Functions.ReadName),
          QueueSegment(Types.Reference, ref),
          QueueSegment(Types.Text, name),
        ],
        MessageDirection.input,
        raw: payload
    );

    notifyListeners();
  }

  void runMessage(Uint8List data) {
    if (data.isEmpty) return;

    // 1. The first byte is always our Function code
    final int functionValue = data[0];

    // 2. Map the byte to our Functions enum
    final functionCall = Functions.values.firstWhere(
          (f) => f.value == functionValue,
      orElse: () => Functions.None,
    );

    // 3. Prepare the payload (everything after the function byte)
    // We use sublist to pass just the relevant data to the handlers
    final Uint8List payload = data.sublist(1);

    switch (functionCall) {
      case Functions.CreateObject:
        onCreateObjectResponse(payload);
        break;
      case Functions.DeleteObject:
        onDeleteObjectResponse(payload);
        break;
      case Functions.ReadObject:
        onReadObjectResponse(payload);
        break;
      case Functions.SaveObject:
        onSaveObjectResponse(payload);
        break;
      case Functions.ReadValue:
        readValue(payload);
        break;
      case Functions.ReadInfo:
        onReadInfoResponse(payload);
        break;
      case Functions.Report:
        handleReport(payload);
        break;
      case Functions.ReadName: // Or Functions.WriteName if the MCU uses the same code for echo
        onReadNameResponse(payload);
        break;
      default:
        print("Function $functionCall (Byte: $functionValue) not implemented.");
    }
  }
}