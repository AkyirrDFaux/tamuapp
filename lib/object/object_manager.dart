import 'package:flutter/material.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../message/message.dart';
import 'object.dart';
import '../types.dart';
import '../functions.dart';
import 'dart:collection';

class ObjectManager extends ChangeNotifier {
  static final ObjectManager _instance = ObjectManager._internal();

  factory ObjectManager() {
    return _instance;
  }

  ObjectManager._internal();

  final List<Object> _objects = [];
  UnmodifiableListView<Object> get objects => UnmodifiableListView(_objects);



  void reloadObjects() {
    // Clear the existing objects
    _objects.clear();

    Message message = Message();
    message.addSegment(Types.Function, Functions.Refresh);
    BluetoothManager().sendMessage(message);

    // Notify listeners that the data has changed
    notifyListeners();
  }

  void SaveAll() {
    Message message = Message();
    message.addSegment(Types.Function, Functions.SaveAll);
    BluetoothManager().sendMessage(message);
  }

  void addObject(Object obj) {
    _objects.add(obj);
    notifyListeners();
  }

  Object? getObjectById(int id) {
    try {
      return objects.firstWhere((obj) => obj.id == id);
    } catch (e) {
      return null;
    }
  }

  void ReadObject(Message message){
    Object newObject;
      if(message.getSegmentType(2) == Types.ID
      && message.getSegmentType(1) == Types.ObjectType){
        int id = message.getSegmentData(2);
        ObjectTypes type = message.getSegmentData(1);
        Object? existingObject = getObjectById(id);
        if (existingObject != null) {
          newObject = existingObject;
        }
        else{
          newObject = Object(type: type, id: id);
        }
      }
      else {
        return;
      }
      
      if(message.getSegmentType(3) == Types.Flags){
        newObject.flags = message.getSegmentData(3);
      }
      if(message.getSegmentType(4) == Types.Text && message.getSegmentData(4) != null){
        newObject.name = message.getSegmentData(4);
      }
      if(message.getSegmentType(5) == Types.IDList){
        newObject.modules = message.getSegmentData(5);
      }
      List<MapEntry<Types, dynamic>> values = [];
      for (int i = 6; i < message.segmentCount; i++) {
        values.add(MapEntry(message.getSegmentType(i), message.getSegmentData(i)));
      }
      newObject.value = values;

      if (!_objects.contains(newObject)){
        addObject(newObject);
      }
      else{
        notifyListeners();
      }
  }

  void WriteValue(Message message){
    Object? thatObject;
    int id = 0;
    if(message.getSegmentType(1) == Types.ID){
      id = message.getSegmentData(1);
      // To get the lowest byte of the ID, we can perform a bitwise AND with 0xFF.
      // 0xFF in hexadecimal is 11111111 in binary.
      // This operation will keep the lower 8 bits and set all higher bits to 0.
      int objectId = id & 0xFFFFFF00;
      thatObject = getObjectById(objectId);
    }
    if (thatObject == null){
      return;
    }

    int lowestByte = id & 0xFF; // [1, 4]

    if (lowestByte != 0) {
      // If the lowest byte is not zero, there's only one value in the message.
      if (message.segmentCount > 2) {
        int index = lowestByte - 1;
        if (index < thatObject.value.length) {
          // Update the value at the specified index. [3]
          thatObject.value[index] = MapEntry(message.getSegmentType(2), message.getSegmentData(2));
        }
      }
    } else {
      // Otherwise, read all values from the message.
      List<MapEntry<Types, dynamic>> values = [];
      for (int i = 2; i < message.segmentCount; i++) {
        values.add(MapEntry(message.getSegmentType(i), message.getSegmentData(i)));
      }
      thatObject.value = values;
    }

    notifyListeners();
  }


  void SetFlags(Message message) {
    if (message.getSegmentType(1) == Types.ID &&
        message.getSegmentType(2) == Types.Flags) {
      int id = message.getSegmentData(1);
      Object? targetObject = getObjectById(id);

      if (targetObject != null) {
        targetObject.flags = message.getSegmentData(2);
        notifyListeners(); // Notify listeners if the object's state changed
      } else {
        // Handle the case where the object with the given ID is not found
        print("Object with ID $id not found.");
      }
    } else {
      // Handle incorrect message format
      print("Invalid message format for SetFlags.");
    }
  }

  void runMessage(Message message){
    if(message.getSegmentType(0) != Types.Function) {
      return;
    }
    switch (message.getSegmentData(0)){
      case Functions.ReadObject:
        ReadObject(message);
        break;
      case Functions.WriteValue:
        WriteValue(message);
        break;
      case Functions.SetFlags: // Assuming you add SetFlags to your Functions enum
        SetFlags(message);
        break;
      default:
        print("Not implemented:" + message.getSegmentData(0).toString());
        break;
    }
  }
}
