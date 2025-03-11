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
      && message.getSegmentType(1) == Types.Type){
        int id = message.getSegmentData(2);
        Types type = message.getSegmentData(1);
        newObject = Object(type: type, id: id);
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
      if(message.getSegmentType(6) == newObject.type){
        newObject.value = message.getSegmentData(6);
      }

      addObject(newObject);
  }

  void WriteValue(Message message){
    Object? thatObject;
    if(message.getSegmentType(1) == Types.ID){
      thatObject = getObjectById(message.getSegmentData(1));
    }
    if (thatObject == null){
      return;
    }

    if (message.getSegmentType(2) == thatObject.type){
      thatObject.value = message.getSegmentData(2);
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
      default:
        print("Not implemented:" + message.getSegmentData(0).toString());
        break;
    }
  }
}