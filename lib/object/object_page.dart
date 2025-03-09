
import 'package:flutter/material.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../functions.dart';
import '../message/message.dart';
import '../types.dart';
import 'object.dart';
import '../editables/editable_field.dart';

class ObjectPage extends StatelessWidget {
  final Object object;

  const ObjectPage({
    super.key,
    required this.object,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(object.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              Message message = Message();
              message.addSegment(Types.Function, Functions.DeleteObject);
              message.addSegment(Types.ID, object.id);
              BluetoothManager().sendMessage(message);
              Navigator.pop(context);
            },
          ),
          //Don't use yet, unsafe
          /*IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {

              Message message = Message();
              message.addSegment(Types.Function, Functions.SaveObject);
              message.addSegment(Types.ID, object.id);
              BluetoothManager().sendMessage(message);
            },
          ),*/
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Message message = Message();
              message.addSegment(Types.Function, Functions.ReadObject);
              message.addSegment(Types.ID, object.id);
              BluetoothManager().sendMessage(message);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${object.id}'),
            const SizedBox(height: 8),
            EditableField(
              label: 'Type',
              initialValue: object.type,
              onChanged: (newValue) {
                if(newValue != null){
                  //object.type = newValue;
                }
              },
            ),
            const SizedBox(height: 8),
            EditableField(
              label: 'Name',
              initialValue: object.name,
              onChanged: (newValue) {
                if(newValue != null){
                  Message message = Message();
                  message.addSegment(Types.Function, Functions.WriteName);
                  message.addSegment(Types.ID, object.id);
                  message.addSegment(Types.Text, newValue);
                  BluetoothManager().sendMessage(message);
                }
                //Add a sending function instead
              },
            ),
            const SizedBox(height: 8),
            EditableField(
              label: 'Flags',
              initialValue: object.flags,
              onChanged: (newValue) {
                if(newValue != null){
                  //TODO: Add a sending function
                  /*Message message = Message();
                  message.addSegment(Types.Function, Functions.WriteName);
                  message.addSegment(Types.ID, object.id);
                  message.addSegment(Types.Text, newValue);
                  BluetoothManager().sendMessage(message);*/
                }
                //Add a sending function instead
              },
            ),
            const SizedBox(height: 8),
            EditableField(
              label: 'Modules',
              initialValue: object.modules,
              onChanged: (newValues) {
                if(newValues != null){
                  Message message = Message();
                  message.addSegment(Types.Function, Functions.SetModules);
                  message.addSegment(Types.ID, object.id);
                  message.addSegment(Types.IDList, newValues);
                  BluetoothManager().sendMessage(message);
                }
              },
            ),
            const SizedBox(height: 8),
            EditableField(label: "Value",
              initialValue: object.value,
              onChanged: (newValues){
                if(newValues != null){
                  Message message = Message();
                  message.addSegment(Types.Function, Functions.WriteValue);
                  message.addSegment(Types.ID, object.id);
                  message.addSegment(object.type, newValues);
                  BluetoothManager().sendMessage(message);
                }
              }
            ),
          ],
        ),
      ),
    );
  }
}