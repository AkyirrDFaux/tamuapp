import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'object_manager.dart'; // Import your ObjectManager
import 'object_page.dart';
import 'new_object_page.dart';

class ObjectListPage extends StatelessWidget {
  const ObjectListPage({Key? key}) : super(key: key);

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
          final objects = manager.objects;

          if (objects.isEmpty) {
            return const Center(
              child: Text('No objects available.'),
            );
          }

          return ListView.builder(
            itemCount: objects.length,
            itemBuilder: (context, index) {
              final object = objects[index];
              return ListTile(
                title: Text(object.name),
                subtitle: Text(object.id.toString()),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ObjectPage(object: object),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}