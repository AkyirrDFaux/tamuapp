import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../editables/value_display.dart';
import '../functions.dart';
import '../message/message.dart';
import '../object/object_manager.dart';
import '../types.dart';
import 'object.dart';
import '../editables/editable_field.dart';
import '../flags.dart';

class FlagsIconRow extends StatelessWidget {
  final Object object;

  const FlagsIconRow({super.key, required this.object});

  // --- This method has been simplified ---
  void _toggleFlag(BuildContext context, Flags flag) {
    // The core toggle logic remains simple due to the guard in _buildFlagIcon
    final newFlags = FlagClass(object.flags.value ^ flag.value);

    // Send the message to update the flags
    Message message = Message();
    message.addSegment(Types.Function, Functions.SetFlags);
    message.addSegment(Types.ID, object.id);
    message.addSegment(Types.Flags, newFlags);
    BluetoothManager().sendMessage(message);
    // The UI will update automatically via the Consumer once the ObjectManager is updated
  }

  Widget _buildFlagIcon(BuildContext context,
      {required Flags flag, required IconData icon, required String tooltip}) {
    final bool isActive = object.flags.hasFlag(flag);
    final Color activeColor = Theme.of(context).colorScheme.primary;
    final Color inactiveColor = Theme.of(context).disabledColor;

    // --- Logic for the read-only 'auto' flag ---
    if (flag == Flags.auto) {
      return Tooltip(
        message: '$tooltip (${isActive ? "Enabled" : "Disabled"})',
        child: Padding(
          // Add padding to align it with the other IconButtons
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            icon,
            color: isActive ? activeColor : inactiveColor,
          ),
        ),
      );
    }

    // --- Logic to disable the mutually exclusive buttons ---
    bool isBlocked = false;
    String disabledTooltip = tooltip;

    if (flag == Flags.runLoop && object.flags.hasFlag(Flags.runOnce)) {
      isBlocked = true;
      disabledTooltip = 'Cannot enable Run Loop while Run Once is active';
    } else if (flag == Flags.runOnce && object.flags.hasFlag(Flags.runLoop)) {
      isBlocked = true;
      disabledTooltip = 'Cannot enable Run Once while Run Loop is active';
    }

    return IconButton(
      icon: Icon(icon),
      color: isActive ? activeColor : inactiveColor,
      onPressed:
      isActive || !isBlocked ? () => _toggleFlag(context, flag) : null,
      tooltip: isBlocked
          ? disabledTooltip
          : '$tooltip (${isActive ? "Enabled" : "Disabled"})',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Wrap(
          spacing: 8.0, // Horizontal space between icons
          runSpacing: 4.0, // Vertical space between icon rows
          children: [
            _buildFlagIcon(
              context,
              flag: Flags.auto,
              icon: Icons.settings_outlined,
              tooltip: 'Auto',
            ),
            _buildFlagIcon(
              context,
              flag: Flags.runLoop,
              icon: Icons.play_arrow_outlined,
              tooltip: 'Run Loop',
            ),
            _buildFlagIcon(
              context,
              flag: Flags.runOnce,
              icon: Icons.one_x_mobiledata_outlined,
              tooltip: 'Run Once',
            ),
            _buildFlagIcon(
              context,
              flag: Flags.runOnStartup,
              icon: Icons.power_settings_new_outlined,
              tooltip: 'Run on Startup',
            ),
            _buildFlagIcon(
              context,
              flag: Flags.favourite,
              icon: Icons.favorite_border,
              tooltip: 'Favourite',
            ),
            _buildFlagIcon(
              context,
              flag: Flags.inactive,
              icon: Icons.block_outlined,
              tooltip: 'Inactive',
            ),
            // Add more icons for other flags as needed
          ],
        ),
      ],
    );
  }
}

class ObjectPage extends StatefulWidget {
  final Object object;

  const ObjectPage({
    super.key,
    required this.object,
  });

  @override
  State<ObjectPage> createState() => _ObjectPageState();
}

class _ObjectPageState extends State<ObjectPage> {
  @override
  void initState() {
    super.initState();
  }

  void _refreshObject() {
    Message message = Message();
    message.addSegment(Types.Function, Functions.ReadObject);
    message.addSegment(Types.ID, widget.object.id);
    BluetoothManager().sendMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    // Use a Consumer to listen for changes in ObjectManager
    return Consumer<ObjectManager>(
      builder: (context, objectManager, child) {
        // Get the latest version of the object from the ObjectManager
        final object = objectManager.getObjectById(widget.object.id);

        // Handle case where the object might have been deleted or not found
        if (object == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Object Not Found"),
            ),
            body: const Center(
              child:
              Text("This object could not be found in the Object Manager."),
            ),
          );
        }

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
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshObject,
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.tag_outlined),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("ID", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(object.formattedId),
                          ],
                        ),
                      ),
                      // ID is read-only, so no EditField is needed.
                      // An empty SizedBox keeps the alignment consistent.
                      const SizedBox(width: 48), // Width of a typical icon button
                    ],
                  ),
                  const SizedBox(height: 16), // Increased spacing

                  // --- NEW: Formatted Type Section ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.type_specimen_outlined),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Type", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(object.type.toString().split('.').last),
                          ],
                        ),
                      ),
                      // Type is also read-only.
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 16), // Increased spacing

                  // --- MODIFIED: Name Section (Label added for consistency) ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.label_outline),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Name", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(object.name),
                          ],
                        ),
                      ),
                      EditField(
                          label: 'Name',
                          initialValue: object.name,
                          onChanged: (newValue) {
                            if (newValue != null) {
                              Message message = Message();
                              message.addSegment(
                                  Types.Function, Functions.WriteName);
                              message.addSegment(Types.ID, object.id);
                              message.addSegment(Types.Text, newValue);
                              BluetoothManager().sendMessage(message);
                            }
                          },
                          type: Types.Text
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FlagsIconRow(object: object),
                  const SizedBox(height: 16), // Increased spacing

                  // --- MODIFIED 'MODULES' SECTION ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.device_hub_outlined),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Modules", style: TextStyle(fontWeight: FontWeight.bold)),
                            ValueDisplay(
                              value: object.modules,
                              type: Types.IDList, // Use the correct type for formatting
                            ),
                          ],
                        ),
                      ),
                      EditField(
                          label: 'Modules',
                          initialValue: object.modules,
                          onChanged: (newValues) {
                            if (newValues != null) {
                              Message message = Message();
                              message.addSegment(
                                  Types.Function, Functions.SetModules);
                              message.addSegment(Types.ID, object.id);
                              message.addSegment(Types.IDList, newValues);
                              BluetoothManager().sendMessage(message);
                            }
                          },
                          type: Types.IDList
                      ),
                    ],
                  ),
                  const SizedBox(height: 16), // Increased spacing

                  // --- MODIFIED 'VALUE' SECTION TO DISPLAY A LIST ---
                  const Row(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.data_object_outlined),
                      ),
                      Text("Values", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Iterate through the list of values and display each one in a row
                  for (var i = 0; i < object.value.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(width: 32), // Indent the value rows
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(object.value[i].key.toString().split('.').last, style: const TextStyle(fontWeight: FontWeight.w500)),
                                ValueDisplay(
                                  value: object.value[i].value,
                                  type: object.value[i].key,
                                ),
                              ],
                            ),
                          ),
                          EditField(
                              label: "Value",
                              initialValue: object.value[i].value,
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  // When one value changes, send only the changed value.
                                  // The ID is the object ID + index + 1.
                                  Message message = Message();
                                  message.addSegment(Types.Function, Functions.WriteValue);
                                  message.addSegment(Types.ID, object.id + i + 1);
                                  message.addSegment(object.value[i].key, newValue);
                                  BluetoothManager().sendMessage(message);
                                }
                              },
                              type: object.value[i].key),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
