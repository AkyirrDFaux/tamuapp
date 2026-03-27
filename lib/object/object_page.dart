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
    // 1. Double-check protection: Never modify Auto
    if (flag == Flags.auto) return;

    final newInfo = ObjectInfo(
      flags: FlagClass(object.info.flags.value ^ flag.value),
      runTiming: object.info.runTiming,
    );

    ObjectManager().writeInfo(object.id, newInfo);
  }

  /// Builds a standard interactive IconButton for user-managed flags
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

  /// Builds a non-interactive, read-only indicator for MCU-managed flags
  Widget _buildReadOnlyFlagIndicator(BuildContext context, {required Flags flag, required IconData icon, required String tooltip}) {
    final theme = Theme.of(context);
    final bool isActive = object.info.flags.has(flag);

    // 2. Visual Priority: Auto flag uses Amber when active to show system control
    final Color activeColor = Colors.amber;
    final Color iconColor = isActive ? activeColor : theme.disabledColor;

    // InkWell with no callbacks provides the tooltip and visual bounds
    // without standard button interaction or dimming.
    return InkWell(
      onTap: null, // Disabled
      mouseCursor: SystemMouseCursors.basic, // Show it's not a button
      child: Tooltip(
        message: '$tooltip (Read-Only)',
        child: Container(
          // Match standard IconButton sizing/padding
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            // 3. Keep background highlight if active
            color: isActive ? activeColor.withOpacity(0.1) : null,
            borderRadius: BorderRadius.circular(20), // Circular background
          ),
          child: Icon(
            icon,
            color: iconColor, // 4. Lit up with bright amber if active
            size: 24, // Standard IconButton icon size
          ),
        ),
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
        crossAxisAlignment: WrapCrossAlignment.center, // Align icons vertically
        children: [
          // Auto uses the Special Read-Only Indicator
          _buildReadOnlyFlagIndicator(context, flag: Flags.auto, icon: Icons.hdr_auto_outlined, tooltip: 'Auto-Generated'),

          // User Flags use the standard Interactive Buttons
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ObjectManager>(
      builder: (context, objectManager, child) {
        final object = objectManager.getObjectByRef(widget.object.id);
        if (object == null) {
          return const Scaffold(body: Center(child: Text("Object not found")));
        }

        final entries = object.values.values.toList();
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
            title: Text(object.name),
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
                        right: 8, top: 8,
                        child: Container(width: 8, height: 8,
                            decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
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
                _buildInfoSection(
                  icon: Icons.timer_outlined,
                  label: "RUN TIMING",
                  value: "${object.info.runTiming}",
                  theme: theme,
                  onTap: () => _openEditor(context, object.id, object.info.runTiming, Types.Byte),
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
                        onTap: () => _openEditor(context, Reference(object.id.net, object.id.group, object.id.device, entry.path), entry.data, entry.type),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withOpacity(0.2),
                            border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("PATH: ${entry.path.pathString} (${entry.type.name})",
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white38)),
                                    const SizedBox(height: 4),
                                    ValueDisplay(value: entry.data, type: entry.type),
                                  ],
                                ),
                              ),
                              if (!isEditMode && entry.type == Types.Reference && entry.data is Reference)
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward, size: 20),
                                  onPressed: () {
                                    final target = objectManager.getObjectByRef(entry.data as Reference);
                                    if (target != null) {
                                      _stopTimer(); // CRITICAL: Stop refreshing before navigating away
                                      Navigator.push(context, MaterialPageRoute(builder: (c) => ObjectPage(object: target)));
                                    }
                                  },
                                ),
                              if (isEditMode && !hasChildren)
                                IconButton(
                                  icon: const Icon(Icons.subdirectory_arrow_right, size: 18, color: Colors.white38),
                                  onPressed: () => _openEditor(context, Reference(object.id.net, object.id.group, object.id.device, generateChildPath(entry.path)), null, Types.Undefined),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
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