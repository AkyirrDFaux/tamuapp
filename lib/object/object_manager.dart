import 'package:flutter/material.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../info.dart';
import '../message/message.dart';
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
    _objects[obj.id.fullAddress] = obj;
    notifyListeners();
  }

  NodeObject? getObjectByRef(Reference ref) {
    return _objects[ref.fullAddress];
  }

  /// Update a value via global Reference (updates the specific path within that reference)
  void updateObjectValue(Reference targetRef, Types type, dynamic data) {
    final obj = getObjectByRef(targetRef);
    if (obj != null) {
      // Use the Path portion of the reference to update the object
      obj.updateValue(targetRef.location, type, data);
      notifyListeners();
    }
  }

  void reloadObjects() {
    _objects.clear();

    Message message = Message();
    // Assuming addSegment now maps to path-based entries
    message.addSegment(Types.Function, Functions.Refresh);

    BluetoothManager().sendMessage(message);
    notifyListeners();
  }

  void refreshObject(Reference ref) {
    Message message = Message();
    message.addSegment(Types.Function, Functions.ReadObject);
    message.addSegment(Types.Reference, ref);
    BluetoothManager().sendMessage(message);
  }

  void createObject(Reference ref, ObjectTypes type) {
    Message message = Message();
    message.addSegment(Types.Function, Functions.CreateObject);
    message.addSegment(Types.Reference, ref);
    message.addSegment(Types.ObjectType, type);

    BluetoothManager().sendMessage(message);
  }

  void onCreateObjectResponse(Message message) {
    final entries = message.valueEntries;
    if (entries.length < 3) return;

    // Segment 1: ObjectType, Segment 2: Reference
    final ObjectTypes objType = entries[1].data as ObjectTypes;
    final dynamic refData = entries[2].data;
    final Reference objRef = (refData is Reference) ? refData : Reference.fromList(refData);

    // 1. Register a placeholder object so the UI knows it exists
    NodeObject newObj = NodeObject(type: objType, id: objRef);
    registerObject(newObj);

    // 2. Follow up with a refresh to get flags, name, and tree values
    refreshObject(objRef);
  }

  void deleteObject(Reference ref) {
    Message message = Message();
    message.addSegment(Types.Function, Functions.DeleteObject);
    message.addSegment(Types.Reference, ref);

    BluetoothManager().sendMessage(message);
  }

  void onDeleteObjectResponse(Message message) {
    final entries = message.valueEntries;
    if (entries.length < 2) return;

    // Segment 1: The Reference of the deleted object
    final dynamic refData = entries[1].data;
    final Reference objRef = (refData is Reference) ? refData : Reference.fromList(refData);

    // Remove from local state now that hardware has confirmed destruction
    _objects.remove(objRef.fullAddress);
    notifyListeners();
  }

  void saveAll() {
    Message message = Message();
    message.addSegment(Types.Function, Functions.SaveAll);
    BluetoothManager().sendMessage(message);
  }

  void saveObject(Reference ref) {
    Message message = Message();
    message.addSegment(Types.Function, Functions.SaveObject);
    message.addSegment(Types.Reference, ref);

    BluetoothManager().sendMessage(message);
  }

  void onSaveObjectResponse(Message message) {
    final entries = message.valueEntries;
    if (entries.length < 2) return;

    final dynamic refData = entries[1].data;
    final Reference objRef = (refData is Reference) ? refData : Reference.fromList(refData);

    // Optional: You could update a "isDirty" flag here if your NodeObject has one
    print("Object ${objRef.fullAddress} saved successfully to MCU Flash.");
  }

  /// [0]Func, [1]Ref, [2]Type, [3]Flags, [4]Name, [5+]Values
  void readObject(Message message) {
    final entries = message.valueEntries;
    if (entries.length < 5) return;

    // 1. Identity
    final dynamic refData = entries[1].data;
    final Reference objRef = (refData is Reference) ? refData : Reference.fromList(refData);
    final ObjectTypes objType = entries[2].data as ObjectTypes;

    // 2. Find or Create
    NodeObject targetObject = getObjectByRef(objRef) ?? NodeObject(type: objType, id: objRef);

    // 3. Metadata - UPDATED: Now expects ObjectInfo instead of just FlagClass
    if (entries[3].data is ObjectInfo) {
      targetObject.info.flags.value = (entries[3].data as ObjectInfo).flags.value;
      targetObject.info.runPeriod = (entries[3].data as ObjectInfo).runPeriod;
    }

    if (entries[4].data is String) {
      targetObject.name = entries[4].data;
    }

    // 4. Process Tree Values
    for (int i = 5; i < entries.length; i++) {
      final entry = entries[i];
      final List<int> rawIndices = List<int>.from(entry.path.indices);
      if (rawIndices.isNotEmpty) {
        rawIndices[0] -= 5;
      }
      targetObject.updateValue(Path(rawIndices), entry.type, entry.data);
    }

    registerObject(targetObject);
  }

  /// [0]Func, [1]Ref, [2+]Values
  void readValue(Message message) {
    final entries = message.valueEntries;
    // Segment 1: Reference (contains Net, Group, Dev, AND Path)
    // Segment 2: Data (The actual value)
    if (entries.length < 2) return;

    final dynamic refData = entries[1].data;
    final Reference objRef = (refData is Reference) ? refData : Reference.fromList(refData);

    final targetObject = getObjectByRef(objRef);
    if (targetObject == null) return;

    if (entries.length >= 3) {
      // Use the Path stored inside objRef to place the data at the correct tree node
      targetObject.updateValue(objRef.location, entries[2].type, entries[2].data);
      notifyListeners();
    }
  }

  /// Sends a new value to the MCU at the specified Reference (Address + Path)
  void writeValue(Reference ref, dynamic value, {required Types type}) {
    Message message = Message();
    message.addSegment(Types.Function, Functions.WriteValue);
    message.addSegment(Types.Reference, ref);
    message.addSegment(type, value);

    BluetoothManager().sendMessage(message);
    // Reminder: Optimistic update removed per request.
    // UI will update when MCU echoes back the ReadValue response.
  }

  void onReadInfoResponse(Message message) {
    final entries = message.valueEntries;
    if (entries.length < 3) return;

    final dynamic refData = entries[1].data;
    final Reference objRef = (refData is Reference) ? refData : Reference.fromList(refData);

    final targetObject = getObjectByRef(objRef);
    if (targetObject != null && entries[2].data is ObjectInfo) {
      final ObjectInfo newInfo = entries[2].data as ObjectInfo;
      targetObject.info.flags.value = newInfo.flags.value;
      targetObject.info.runPeriod = newInfo.runPeriod;
      targetObject.info.runPhase = newInfo.runPhase;
      notifyListeners();
    }
  }

  /// Sends a request to update the ObjectInfo (Flags + Timing) on the MCU
  void writeInfo(Reference ref, ObjectInfo info) {
    Message message = Message();
    message.addSegment(Types.Function, Functions.SetInfo);
    message.addSegment(Types.Reference, ref);
    message.addSegment(Types.ObjectInfo, info); // Ensure Types.ObjectInfo exists in your enum

    BluetoothManager().sendMessage(message);
  }

  void runMessage(Message message) {
    if (message.valueEntries.isEmpty) return;

    final firstEntry = message.valueEntries.first;
    if (firstEntry.type != Types.Function) return;

    Functions functionCall;
    if (firstEntry.data is Functions) {
      functionCall = firstEntry.data as Functions;
    } else {
      functionCall = Functions.values.firstWhere(
            (f) => f.value == firstEntry.data,
        orElse: () => Functions.None,
      );
    }

    switch (functionCall) {
      case Functions.CreateObject:
        onCreateObjectResponse(message);
        break;
      case Functions.DeleteObject:
        onDeleteObjectResponse(message);
        break;
      case Functions.ReadObject:
        readObject(message);
        break;
      case Functions.SaveObject:
        onSaveObjectResponse(message);
        break;
      case Functions.ReadValue:
        readValue(message);
        break;
      case Functions.ReadInfo:
        onReadInfoResponse(message);
        break;
      default:
        print("Function $functionCall not implemented.");
    }
  }
}