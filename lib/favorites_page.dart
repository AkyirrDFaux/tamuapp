import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'object/object_manager.dart';
import 'object/object.dart';
import 'message/message.dart';
import 'bluetooth/bluetooth_manager.dart';
import 'types.dart';
import 'flags.dart';
import 'functions.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Programs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<ObjectManager>(context, listen: false).reloadObjects();
            },
          ),
        ],
      ),
      body: Consumer<ObjectManager>(
        builder: (context, manager, child) {
          final favoritePrograms = manager.objects
              .where((obj) =>
          obj.type == Types.Program &&
              (obj.flags.value & Flags.favourite.value) != 0)
              .toList();

          if (favoritePrograms.isEmpty) {
            return const Center(
              child: Text(
                'No favorite programs found.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: favoritePrograms.length,
            itemBuilder: (context, index) {
              final program = favoritePrograms[index];
              return FavoriteProgramCard(program: program);
            },
          );
        },
      ),
    );
  }
}

class FavoriteProgramCard extends StatelessWidget {
  final Object program;

  const FavoriteProgramCard({super.key, required this.program});

  @override
  Widget build(BuildContext context) {
    final bool isRunningOnce = (program.flags.value & Flags.runOnce.value) != 0;
    final bool isLooping = (program.flags.value & Flags.runLoop.value) != 0;
    final bool isRunning = isRunningOnce || isLooping;

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              program.name,
              style: const TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            if (isRunning)
              _buildActionButton(
                // Dynamically set the label based on the running state
                label: isLooping ? 'Stop Loop' : 'Stop',
                icon: Icons.stop,
                // Use a different color depending on the state for better feedback
                backgroundColor: isLooping ? Colors.orange.shade800 : Colors.red,
                onPressed: () {
                  // The logic remains the same: clear both run flags
                  Message message = Message();
                  message.addSegment(Types.Function, Functions.SetFlags);
                  message.addSegment(Types.ID, program.id);
                  message.addSegment(
                    Types.Flags,
                    FlagClass(program.flags.value & ~(Flags.runLoop.value | Flags.runOnce.value)),
                  );
                  BluetoothManager().sendMessage(message);
                },
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Play Once',
                      icon: Icons.play_arrow,
                      onPressed: () {
                        // Send message to set the runOnce flag
                        Message message = Message();
                        message.addSegment(Types.Function, Functions.SetFlags);
                        message.addSegment(Types.ID, program.id);
                        message.addSegment(
                          Types.Flags,
                          FlagClass(program.flags.value | Flags.runOnce.value),
                        );
                        BluetoothManager().sendMessage(message);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Play Loop',
                      icon: Icons.loop,
                      onPressed: () {
                        // Send message to set the runLoop flag
                        Message message = Message();
                        message.addSegment(Types.Function, Functions.SetFlags);
                        message.addSegment(Types.ID, program.id);
                        message.addSegment(
                          Types.Flags,
                          FlagClass(program.flags.value | Flags.runLoop.value),
                        );
                        BluetoothManager().sendMessage(message);
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Colors.grey[300],
        foregroundColor: backgroundColor == null ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }
}
