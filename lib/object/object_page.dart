import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tamuapp/object/value_editor.dart';
import '../bluetooth/bluetooth_manager.dart';
import 'value_display.dart';
import '../functions.dart';
import '../message/message.dart';
import '../object/object_manager.dart';
import '../types.dart';
import 'object.dart';
import '../info.dart';

class FlagsIconRow extends StatelessWidget {
  final NodeObject object;
  const FlagsIconRow({super.key, required this.object});

  void _toggleFlag(BuildContext context, Flags flag) {
    // Create a copy of the current info to modify
    final newInfo = ObjectInfo(
      flags: FlagClass(object.info.flags.value ^ flag.value),
      runTiming: object.info.runTiming,
    );

    // Sync the entire Info block (Flags + Timing) to the MCU
    ObjectManager().writeInfo(object.id, newInfo);
  }

  Widget _buildFlagIcon(BuildContext context, {required Flags flag, required IconData icon, required String tooltip}) {
    final theme = Theme.of(context);
    final bool isActive = object.info.flags.has(flag); // Updated to use .has()
    final Color iconColor = isActive ? theme.colorScheme.primary : theme.disabledColor;

    return IconButton(
      icon: Icon(icon),
      color: iconColor,
      style: isActive ? IconButton.styleFrom(backgroundColor: theme.colorScheme.primary.withOpacity(0.1)) : null,
      onPressed: () => _toggleFlag(context, flag),
      tooltip: tooltip,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
      child: Wrap(
        spacing: 4.0, runSpacing: 4.0,
        children: [
          _buildFlagIcon(context, flag: Flags.auto, icon: Icons.hdr_auto_outlined, tooltip: 'Auto-Generated'),
          _buildFlagIcon(context, flag: Flags.runOnce, icon: Icons.looks_one_outlined, tooltip: 'Run Once'),
          _buildFlagIcon(context, flag: Flags.runOnStartup, icon: Icons.power_settings_new_outlined, tooltip: 'Run on Startup'),
          _buildFlagIcon(context, flag: Flags.inactive, icon: Icons.pause_circle_outline, tooltip: 'Inactive/Disabled'),
        ],
      ),
    );
  }
}

class ObjectPage extends StatefulWidget {
  final NodeObject object;
  const ObjectPage({super.key, required this.object});

  @override
  State<ObjectPage> createState() => _ObjectPageState();
}

class _ObjectPageState extends State<ObjectPage> {
  bool isEditMode = false;

  void _openEditor(BuildContext context, NodeObject object, Reference ref, dynamic currentData, Types currentType) {
    ValueEditor.show(
      context,
      ref,
      currentData,
      currentType,
          (newType, newVal) {
        context.read<ObjectManager>().writeValue(ref, newVal, type: newType);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ObjectManager>(
      builder: (context, objectManager, child) {
        final object = objectManager.getObjectByRef(widget.object.id);
        if (object == null) {
          return Scaffold(body: const Center(child: Text("Object not found")));
        }

        final entries = object.values.values.toList();

        // Sort entries numerically: [1, 2] comes before [1, 10]
        entries.sort((a, b) {
          num lenA = a.path.indices.length;
          num lenB = b.path.indices.length;
          num minLen = lenA < lenB ? lenA : lenB;

          for (int i = 0; i < minLen; i++) {
            if (a.path.indices[i] != b.path.indices[i]) {
              return a.path.indices[i].compareTo(b.path.indices[i]);
            }
          }
          // If all shared indices are equal, the shorter path comes first
          return lenA.compareTo(lenB);
        });

        // Generates path for a new sibling at a specific depth based on an existing path
        Path generateSiblingPathAtDepth(Path source, int targetDepth) {
          // Ensure we don't try to sublist more than exists
          int safeDepth = targetDepth.clamp(0, source.indices.length);
          List<int> newIndices = List<int>.from(source.indices.sublist(0, safeDepth));

          if (newIndices.isNotEmpty) {
            newIndices[newIndices.length - 1]++;
          } else {
            newIndices = [0]; // Fallback for root
          }
          return Path(newIndices);
        }

        Path generateChildPath(Path parent) {
          List<int> childIndices = List<int>.from(parent.indices);
          childIndices.add(0);
          return Path(childIndices);
        }

        void _confirmDelete(BuildContext context) {
          showDialog(
            context: context,
            builder: (numContext) => AlertDialog(
              content: Text("Are you sure you want to DELETE '${object.name}'?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(numContext),
                  child: const Text("CANCEL"),
                ),
                TextButton(
                  onPressed: () {
                    // 1. Tell MCU to destroy the object
                    ObjectManager().deleteObject(object.id);

                    // 2. Close the dialog
                    Navigator.pop(numContext);

                    // 3. Exit the ObjectPage
                    Navigator.pop(context);
                  },
                  child: const Text("CONFIRM"),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(object.name),
            actions: [
              IconButton(
                icon: Icon(isEditMode ? Icons.check : Icons.edit_note_outlined),
                tooltip: isEditMode ? "Save Changes" : "Toggle Edit Mode",
                onPressed: () {
                  setState(() => isEditMode = !isEditMode);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEditMode ? "Edit Mode Enabled" : "Changes Locked"),
                      duration: const Duration(milliseconds: 800),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: "Refresh from MCU",
                onPressed: () {
                  ObjectManager().refreshObject(object.id);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Refreshing ${object.name}..."),
                      duration: const Duration(milliseconds: 800),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: "Save to Flash",
                onPressed: () {
                  ObjectManager().saveObject(object.id);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Saving ${object.name} to Flash..."),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: "Delete Object",
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(icon: Icons.fingerprint, label: "ADDRESS", value: object.id.toString(), theme: theme),
                _buildInfoSection(icon: Icons.category_outlined, label: "CLASS TYPE", value: object.type.toString().split('.').last, theme: theme),

                const Text("FLAGS & STATE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white38)),
                FlagsIconRow(object: object),
                _buildInfoSection(
                    icon: Icons.timer_outlined,
                    label: "RUN TIMING",
                    value: "${object.info.runTiming}",
                    theme: theme,
                    onTap: () {
                      // Open editor specifically for the RunTiming byte
                      ValueEditor.show(
                          context,
                          object.id,
                          object.info.runTiming,
                          Types.Byte,
                              (type, newValue) {
                            final updatedInfo = ObjectInfo(
                                flags: object.info.flags,
                                runTiming: newValue as int
                            );
                            ObjectManager().writeInfo(object.id, updatedInfo);
                          }
                      );
                    }
                ),
                const Divider(height: 16),

                Row(
                  children: [
                    Icon(Icons.terminal, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text("DATA TREE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),

                ...entries.asMap().entries.expand((mapEntry) {
                  final int index = mapEntry.key;
                  final entry = mapEntry.value;
                  final Path currentPath = entry.path;
                  final int depth = currentPath.length;

                  // Determine which depths end after this entry
                  int nextDepth = (index < entries.length - 1)
                      ? entries[index + 1].path.length
                      : 0;

                  bool hasChildren = nextDepth > depth;

                  return [
                    // --- NODE CARD ---
                    Padding(
                      padding: EdgeInsets.only(left: (depth - 1) * 20.0, bottom: 6),
                      child: InkWell(
                        onTap: () => _openEditor(context, object, Reference(object.id.net, object.id.group, object.id.device, currentPath), entry.data, entry.type),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withOpacity(0.3),
                            border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                                        children: [
                                          TextSpan(text: "PATH: ${currentPath.pathString} ", style: const TextStyle(color: Colors.white38)),
                                          TextSpan(text: "(${entry.type.name})", style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.6))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ValueDisplay(value: entry.data, type: entry.type),
                                  ],
                                ),
                              ),
                              if (isEditMode && !hasChildren)
                                IconButton(
                                  icon: const Icon(Icons.subdirectory_arrow_right, size: 18, color: Colors.white38),
                                  onPressed: () {
                                    final newPath = generateChildPath(currentPath);
                                    _openEditor(context, object, Reference(object.id.net, object.id.group, object.id.device, newPath), null, Types.Undefined);
                                  },
                                  tooltip: "Add Child ${currentPath.pathString}.0",
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // --- SIBLING INSERTION SLOTS ---
                    // If we are in edit mode, and the next node is shallower (or this is the end),
                    // we show a button for every layer that just "closed".
                    if (isEditMode && nextDepth < depth)
                      ...List.generate(depth - nextDepth, (i) {
                        int targetDepth = depth - i;
                        Path siblingPath = generateSiblingPathAtDepth(currentPath, targetDepth);

                        return Padding(
                          padding: EdgeInsets.only(left: (targetDepth - 1) * 20.0, bottom: 8, top: 2),
                          child: TextButton.icon(
                            onPressed: () => _openEditor(context, object, Reference(object.id.net, object.id.group, object.id.device, siblingPath), null, Types.Undefined),
                            icon: const Icon(Icons.add_circle_outline, size: 14),
                            label: Text("ADD ${siblingPath.pathString}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary.withOpacity(0.8),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        );
                      }),
                  ];
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Row(
          children: [
            Icon(icon, size: 20, color: onTap != null ? theme.colorScheme.primary : Colors.white54),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38)),
                Text(value, style: const TextStyle(fontSize: 16, fontFamily: 'monospace')),
              ],
            ),
            if (onTap != null) ...[
              const Spacer(),
              const Icon(Icons.edit, size: 14, color: Colors.white24),
            ]
          ],
        ),
      ),
    );
  }
}