import 'package:flutter/material.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../functions.dart';
import '../message/message.dart';
import '../types.dart'; // Import your enum

class NewObjectDialog extends StatefulWidget {
  const NewObjectDialog({super.key});

  @override
  _NewObjectDialogState createState() => _NewObjectDialogState();
}

class _NewObjectDialogState extends State<NewObjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  Types _selectedType = Types.Undefined; // Default type

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Object'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'ID',
                  hintText: 'Enter object ID',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an ID';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<Types>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                ),
                items: Types.values.map((Types type) {
                  return DropdownMenuItem<Types>(
                    value: type,
                    child: Text(type.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (Types? newValue) {
                  setState(() {
                    _selectedType = newValue!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: const Text('Create'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Message message = Message();
              message.addSegment(Types.Function, Functions.CreateObject);
              message.addSegment(Types.ObjectType, _selectedType);
              message.addSegment(Types.ID, int.parse(_idController.text));
              BluetoothManager().sendMessage(message);
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}

// Example of how to show the dialog:
void showNewObjectDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return const NewObjectDialog();
    },
  );
}