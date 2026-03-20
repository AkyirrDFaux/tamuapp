import 'package:flutter/material.dart';
import 'package:tamuapp/object/object_manager.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../functions.dart';
import '../message/message.dart';
import '../types.dart';
import '../object/object.dart'; // Ensure this is imported

class NewObjectDialog extends StatefulWidget {
  const NewObjectDialog({super.key});

  @override
  _NewObjectDialogState createState() => _NewObjectDialogState();
}

class _NewObjectDialogState extends State<NewObjectDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for the Reference components
  final _netController = TextEditingController(text: "0");
  final _groupController = TextEditingController(text: "0");
  final _deviceController = TextEditingController();

  ObjectTypes _selectedType = ObjectTypes.Undefined;

  @override
  void dispose() {
    _netController.dispose();
    _groupController.dispose();
    _deviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Object'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selection for Object Type
              DropdownButtonFormField<ObjectTypes>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Object Type'),
                items: ObjectTypes.values.map((ObjectTypes type) {
                  return DropdownMenuItem<ObjectTypes>(
                    value: type,
                    child: Text(type.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (ObjectTypes? newValue) {
                  setState(() => _selectedType = newValue!);
                },
              ),
              const SizedBox(height: 16),
              const Text("Address (Reference)", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _netController,
                      decoration: const InputDecoration(labelText: 'Net'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _groupController,
                      decoration: const InputDecoration(labelText: 'Grp'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _deviceController,
                      decoration: const InputDecoration(labelText: 'Dev'),
                      keyboardType: TextInputType.number,
                      validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: const Text('Create'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // Create the Reference object
              final ref = Reference(
                int.tryParse(_netController.text) ?? 0,
                int.tryParse(_groupController.text) ?? 0,
                int.tryParse(_deviceController.text) ?? 0,
                Path([]), // New objects start at root path
              );

              // Use the manager instead of manual message building
              ObjectManager().createObject(ref, _selectedType);

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