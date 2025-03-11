import 'package:flutter/material.dart';

class MapDialog extends StatefulWidget {
  final String label;
  final List<MapEntry<int, int>> initialValue;
  final ValueChanged<List<MapEntry<int, int>>> onChanged;

  const MapDialog({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<MapDialog> createState() => _MapDialogState();
}

class _MapDialogState extends State<MapDialog> {
  late List<MapEntry<int, int>> currentMap;
  late List<TextEditingController> keyControllers;
  late List<TextEditingController> valueControllers;

  @override
  void initState() {
    super.initState();
    currentMap = List<MapEntry<int, int>>.from(widget.initialValue);
    keyControllers = currentMap
        .map((entry) => TextEditingController(text: entry.key.toString()))
        .toList();
    valueControllers = currentMap
        .map((entry) => TextEditingController(text: entry.value.toString()))
        .toList();
  }

  @override
  void dispose() {
    for (var controller in keyControllers) {
      controller.dispose();
    }
    for (var controller in valueControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.label}'),
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < currentMap.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: keyControllers[i],
                            decoration: const InputDecoration(
                              hintText: 'Key',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: valueControllers[i],
                            decoration: const InputDecoration(
                              hintText: 'Value',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            setState(() {
                              currentMap.removeAt(i);
                              keyControllers.removeAt(i);
                              valueControllers.removeAt(i);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                TextButton(
                  child: const Text('Add Entry'),
                  onPressed: () {
                    setState(() {
                      currentMap.add(const MapEntry(0, 0));
                      keyControllers.add(TextEditingController(text: '0'));
                      valueControllers.add(TextEditingController(text: '0'));
                    });
                  },
                ),
              ],
            ),
          );
        },
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Save'),
          onPressed: () {
            List<MapEntry<int, int>> newMap = [];
            for (int i = 0; i < currentMap.length; i++) {
              int? newKey = int.tryParse(keyControllers[i].text);
              int? newValue = int.tryParse(valueControllers[i].text);
              if (newKey != null && newValue != null) {
                newMap.add(MapEntry(newKey, newValue));
              }
            }
            widget.onChanged(newMap);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}