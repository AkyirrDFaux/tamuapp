import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../functions.dart';
import '../message/message.dart';
import '../types.dart';
import '../flags.dart';
import 'object_manager.dart'; // Import your ObjectManager
import 'object_page.dart';
import 'object.dart';
import 'new_object_page.dart';

class ObjectListPage extends StatelessWidget {
  const ObjectListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showNewObjectDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              // Access the ObjectManager and call the reload method
              final manager = Provider.of<ObjectManager>(context, listen: false);
              manager.SaveAll();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Access the ObjectManager and call the reload method
              final manager = Provider.of<ObjectManager>(context, listen: false);
              manager.reloadObjects();
            },
          ),
        ],
      ),
      body: Consumer<ObjectManager>(
        builder: (context, manager, child) {
          // Access the list of objects from ObjectManager
          final allObjects = manager.objects;

          if (allObjects.isEmpty) {
            return const Center(
              child: Text('No objects available.'),
            );
          }

          // Separate favorite and non-favorite objects
          final favoriteObjects = allObjects
              .where((obj) => (obj.flags.value & Flags.favourite.value) != 0)
              .toList();
          final otherObjects = allObjects
              .where((obj) => (obj.flags.value & Flags.favourite.value) == 0)
              .toList();

          // Combine the lists, adding a delimiter if necessary
          final List<dynamic> displayList = [];
          displayList.addAll(favoriteObjects);
          if (favoriteObjects.isNotEmpty && otherObjects.isNotEmpty) {
            displayList.add(const Divider(thickness: 1, height: 1)); // Delimiter
          }
          displayList.addAll(otherObjects);


          if (displayList.isEmpty) {
            return const Center(
              child: Text('No objects available.'),
            );
          }

          return ListView.builder(
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final item = displayList[index];

              // Check if the item is an ObjectClass or the Divider
              if (item is Object) { // Assuming your object class is named ObjectClass
                final object = item;
                return ListTile(
                  leading: Icon(getIconForType(object.type)),
                  title: Text(object.name),
                  subtitle: Text('${object.formattedId} - ${object.type.name}'),
                  trailing: object.type == Types.Program
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((object.flags.value &
                      (Flags.runLoop.value | Flags.runOnce.value)) ==
                          0) ...[
                        IconButton(
                          icon: const Icon(Icons.one_x_mobiledata_outlined),
                          onPressed: () {
                            Message message = Message();
                            message.addSegment(
                                Types.Function, Functions.SetFlags);
                            message.addSegment(Types.ID, object.id);
                            message.addSegment(
                                Types.Flags,
                                FlagClass(object.flags.value |
                                Flags.runOnce.value));
                            BluetoothManager().sendMessage(message);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_arrow_outlined),
                          onPressed: () {
                            Message message = Message();
                            message.addSegment(
                                Types.Function, Functions.SetFlags);
                            message.addSegment(Types.ID, object.id);
                            message.addSegment(
                                Types.Flags,
                                FlagClass(object.flags.value |
                                Flags.runLoop.value));
                            BluetoothManager().sendMessage(message);
                          },
                        ),
                      ] else
                        IconButton(
                          icon: const Icon(Icons.stop),
                          onPressed: () {
                            Message message = Message();
                            message.addSegment(
                                Types.Function, Functions.SetFlags);
                            message.addSegment(Types.ID, object.id);
                            message.addSegment(
                                Types.Flags,
                                FlagClass(object.flags.value &
                                ~(Flags.runLoop.value |
                                Flags.runOnce.value)));
                            BluetoothManager().sendMessage(message);
                          },
                        ),
                    ],
                  )
                      : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ObjectPage(object: object),
                      ),
                    );
                  },
                );
              } else if (item is Divider) {
                return item; // Return the Divider widget
              }
              return const SizedBox.shrink(); // Should not happen
            },
          );
        },
      ),
    );
  }
}
