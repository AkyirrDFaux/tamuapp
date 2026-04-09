import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tamuapp/object/value_editor.dart';
import 'value_display.dart';
import '../object/object_manager.dart';
import '../types.dart';
import 'object.dart';
import '../info.dart';

class FlagsIconRow extends StatelessWidget {
  final NodeObject object;
  const FlagsIconRow({super.key, required this.object});

  void _toggleFlag(BuildContext context, Flags flag) {
    // Protection: Never manually modify Auto or Inactive via standard toggle if logic requires it
    if (flag == Flags.auto) return;

    // Create a new FlagClass with the toggled bit
    final updatedFlags = FlagClass(object.info.flags.value ^ flag.value);

    final newInfo = ObjectInfo(
      flags: updatedFlags,
      runPeriod: object.info.runPeriod,
      runPhase: object.info.runPhase,
    );

    ObjectManager().writeInfo(object.id, newInfo);
  }

  Widget _buildInteractiveFlagButton(BuildContext context, {required Flags flag, required IconData icon, required String tooltip}) {
    final theme = Theme.of(context);
    final bool isActive = object.info.flags.has(flag);
    final Color iconColor = isActive ? theme.colorScheme.primary : theme.disabledColor;

    return IconButton(
      icon: Icon(icon),
      color: iconColor,
      tooltip: tooltip,
      onPressed: () => _toggleFlag(context, flag),
      style: isActive
          ? IconButton.styleFrom(backgroundColor: theme.colorScheme.primary.withOpacity(0.1))
          : null,
    );
  }

  Widget _buildReadOnlyFlagIndicator(BuildContext context, {required Flags flag, required IconData icon, required String tooltip}) {
    final theme = Theme.of(context);
    final bool isActive = object.info.flags.has(flag);
    final Color activeColor = Colors.amber;

    return Tooltip(
      message: '$tooltip (System)',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: isActive ? activeColor : theme.disabledColor, size: 24),
      ),
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
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildReadOnlyFlagIndicator(context, flag: Flags.auto, icon: Icons.hdr_auto_outlined, tooltip: 'Auto-Generated'),
          _buildReadOnlyFlagIndicator(context, flag: Flags.dirty, icon: Icons.save_as_outlined, tooltip: 'Not saved'),
          _buildInteractiveFlagButton(context, flag: Flags.runLoop, icon: Icons.sync, tooltip: 'Run Loop'),
          _buildInteractiveFlagButton(context, flag: Flags.runOnce, icon: Icons.looks_one_outlined, tooltip: 'Run Once'),
          _buildInteractiveFlagButton(context, flag: Flags.runOnStartup, icon: Icons.power_settings_new_outlined, tooltip: 'Run on Startup'),
          _buildInteractiveFlagButton(context, flag: Flags.inactive, icon: Icons.pause_circle_outline, tooltip: 'Inactive/Disabled'),
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
  Timer? _refreshTimer;
  double _refreshInterval = 0; // Changed to double for sub-second support

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    setState(() => _refreshInterval = 0);
  }

  void _startTimer(double seconds) {
    _stopTimer();
    if (seconds <= 0) return;

    setState(() => _refreshInterval = seconds);

    // Convert decimal seconds to milliseconds
    int ms = (seconds * 1000).toInt();
    _refreshTimer = Timer.periodic(Duration(milliseconds: ms), (timer) {
      ObjectManager().refreshObject(widget.object.id);
    });
  }

  void _showTimerDialog() {
    // Show current interval (e.g., 0.5) in the text field
    final controller = TextEditingController(
        text: _refreshInterval > 0 ? _refreshInterval.toString() : "0.5");

    showDialog(
      context: context,
      builder: (numContext) => AlertDialog(
        title: const Text("Periodic Refresh"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: "Interval (seconds)",
              hintText: "e.g. 0.2",
              suffixText: "sec"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _stopTimer();
              Navigator.pop(numContext);
            },
            child: const Text("TURN OFF", style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0;
              _startTimer(val);
              Navigator.pop(numContext);
            },
            child: const Text("SET"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, NodeObject object) {
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
              _stopTimer(); // Stop refresh before deleting
              ObjectManager().deleteObject(object.id);
              Navigator.pop(numContext);
              Navigator.pop(context);
            },
            child: const Text("CONFIRM", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, Reference ref, dynamic currentData, Types currentType) {
    ValueEditor.show(context, ref, currentData, currentType, (newType, newVal) {
      context.read<ObjectManager>().writeValue(ref, newVal, type: newType);
    });
  }

  Path generateSiblingPathAtDepth(Path source, int targetDepth) {
    int safeDepth = targetDepth.clamp(0, source.indices.length);
    List<int> newIndices = List<int>.from(source.indices.sublist(0, safeDepth));
    if (newIndices.isNotEmpty) {
      newIndices[newIndices.length - 1]++;
    } else {
      newIndices = [0];
    }
    return Path(newIndices);
  }

  Path generateChildPath(Path parent) {
    return Path([...parent.indices, 0]);
  }

  void _showRenameDialog(NodeObject object) {
    final controller = TextEditingController(text: object.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Object"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Object Name",
            hintText: "Enter new name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              // Usually, the name is stored inside ObjectInfo or
              // handled by a specific name write command in ObjectManager
              ObjectManager().writeName(object.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text("RENAME"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ObjectManager>(
      builder: (context, objectManager, child) {
        final object = objectManager.getObjectByRef(widget.object.id);
        if (object == null) {
          return const Scaffold(body: Center(child: Text("Object deleted or not found")));
        }

        final entries = object.values.values.toList();
        // Sort entries by path depth and index for a tree-like view
        entries.sort((a, b) {
          int minLen = min(a.path.indices.length, b.path.indices.length);
          for (int i = 0; i < minLen; i++) {
            if (a.path.indices[i] != b.path.indices[i]) {
              return a.path.indices[i].compareTo(b.path.indices[i]);
            }
          }
          return a.path.indices.length.compareTo(b.path.indices.length);
        });

        return Scaffold(
          appBar: AppBar(
            // The Title area (Left/Center)
            title: InkWell(
              onTap: () => _showRenameDialog(object),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(object.name),
                    const SizedBox(width: 8),
                    const Icon(Icons.edit, size: 14, color: Colors.white24),
                  ],
                ),
              ),
            ),
            // The Button area (Right side)
            actions: [
              IconButton(
                icon: Icon(isEditMode ? Icons.check : Icons.edit_note_outlined),
                onPressed: () => setState(() => isEditMode = !isEditMode),
              ),
              GestureDetector(
                onLongPress: _showTimerDialog,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ObjectManager().refreshObject(object.id),
                    ),
                    if (_refreshInterval > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () => ObjectManager().saveObject(object.id),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, object),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(icon: Icons.fingerprint, label: "ADDRESS", value: object.id.toString(), theme: theme),
                const Text("FLAGS & STATE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white38)),
                FlagsIconRow(object: object),

                Row(
                  children: [
                    Expanded(
                      child: _buildInfoSection(
                        icon: Icons.timer_outlined,
                        label: "PERIOD (STRIDE)",
                        value: "${object.info.runPeriod} loops",
                        theme: theme,
                        onTap: () => ValueEditor.show(
                          context,
                          object.id,
                          object.info.runPeriod,
                          Types.Byte,
                              (newType, newVal) {
                            final newInfo = ObjectInfo(
                              flags: object.info.flags,
                              runPeriod: (newVal as num).toInt(),
                              runPhase: object.info.runPhase,
                            );
                            ObjectManager().writeInfo(object.id, newInfo);
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildInfoSection(
                        icon: Icons.shutter_speed_outlined,
                        label: "PHASE (OFFSET)",
                        value: "Offset: ${object.info.runPhase}",
                        theme: theme,
                        onTap: () => ValueEditor.show(
                          context,
                          object.id,
                          object.info.runPhase,
                          Types.Byte,
                              (newType, newVal) {
                            final newInfo = ObjectInfo(
                              flags: object.info.flags,
                              runPeriod: object.info.runPeriod,
                              runPhase: (newVal as num).toInt(),
                            );
                            ObjectManager().writeInfo(object.id, newInfo);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),

                ...entries.asMap().entries.expand((mapEntry) {
                  final int idx = mapEntry.key;
                  final entry = mapEntry.value;
                  final int depth = entry.path.length;
                  int nextDepth = (idx < entries.length - 1) ? entries[idx + 1].path.length : 0;
                  bool hasChildren = nextDepth > depth;

                  return [
                    Padding(
                      padding: EdgeInsets.only(left: (depth - 1) * 20.0, bottom: 6),
                      child: InkWell(
                        onTap: entry.isReadOnly
                            ? () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Access Denied: Value is Read-Only"), duration: Duration(seconds: 1))
                        )
                            : () => _openEditor(context, Reference(object.id.net, object.id.group, object.id.device, entry.path), entry.data, entry.type),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: entry.isReadOnly
                                ? Colors.white.withOpacity(0.02)
                                : theme.colorScheme.secondary.withOpacity(0.1),
                            border: Border(
                                left: BorderSide(
                                    color: entry.isReadOnly
                                        ? Colors.grey.withOpacity(0.4)
                                        : theme.colorScheme.primary.withOpacity(0.5),
                                    width: 4
                                )
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text("PATH: ${entry.path.pathString} (${entry.type.name})",
                                            style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white38)),
                                        const SizedBox(width: 8),
                                        if (entry.isReadOnly)
                                          const Icon(Icons.lock_outline, size: 12, color: Colors.amber),
                                        if (entry.isSetupCall)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4),
                                            child: Icon(Icons.settings_input_component, size: 12, color: Colors.cyanAccent),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ValueDisplay(value: entry.data, type: entry.type),
                                  ],
                                ),
                              ),

                              // --- NAVIGATION LOGIC ---
                              if (!isEditMode && entry.type == Types.Reference && entry.data is Reference)
                                Builder(builder: (context) {
                                  final ref = entry.data as Reference;
                                  if (ref.isGlobal) {
                                    return IconButton(
                                      icon: const Icon(Icons.arrow_forward, size: 20, color: Colors.cyanAccent),
                                      onPressed: () {
                                        final rootTargetRef = Reference(ref.net, ref.group, ref.device, Path([]));
                                        final target = objectManager.getObjectByRef(rootTargetRef);
                                        if (target != null) {
                                          _stopTimer();
                                          Navigator.push(context, MaterialPageRoute(builder: (c) => ObjectPage(object: target)));
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("Object ${rootTargetRef.fullAddress} not found"))
                                          );
                                        }
                                      },
                                    );
                                  } else {
                                    return const SizedBox.shrink();
                                  }
                                }),

                              // --- EDIT MODE CONTROLS ---
                              if (isEditMode && !entry.isReadOnly) ...[
                                // Delete Button
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, size: 20, color: Colors.redAccent),
                                  onPressed: () {
                                    final ref = Reference(object.id.net, object.id.group, object.id.device, entry.path);
                                    objectManager.deleteValue(ref);
                                  },
                                ),
                                // Add Child Button (only if no children exist)
                                if (!hasChildren)
                                  IconButton(
                                    icon: const Icon(Icons.subdirectory_arrow_right, size: 18, color: Colors.white38),
                                    onPressed: () => _openEditor(context, Reference(object.id.net, object.id.group, object.id.device, generateChildPath(entry.path)), null, Types.Undefined),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Logic for adding siblings when depth decreases
                    if (isEditMode && nextDepth < depth)
                      ...List.generate(depth - nextDepth, (i) {
                        int targetDepth = depth - i;
                        Path sibPath = generateSiblingPathAtDepth(entry.path, targetDepth);
                        return Padding(
                          padding: EdgeInsets.only(left: (targetDepth - 1) * 20.0, bottom: 8),
                          child: TextButton.icon(
                            onPressed: () => _openEditor(context, Reference(object.id.net, object.id.group, object.id.device, sibPath), null, Types.Undefined),
                            icon: const Icon(Icons.add_circle_outline, size: 14),
                            label: Text("ADD ${sibPath.pathString}", style: const TextStyle(fontSize: 10)),
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

  Widget _buildInfoSection({required IconData icon, required String label, required String value, required ThemeData theme, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, size: 20, color: onTap != null ? theme.colorScheme.primary : Colors.white54),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
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