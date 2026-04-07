import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../functions.dart';
import '../message/message.dart';
import '../types.dart';
import '../info.dart';
import 'object_manager.dart'; // Import your ObjectManager
import 'object_page.dart';
import 'object.dart';
import 'new_object_dialog.dart';

class ObjectListPage extends StatefulWidget {
  const ObjectListPage({super.key});

  @override
  State<ObjectListPage> createState() => _ObjectListPageState();
}

class _ObjectListPageState extends State<ObjectListPage> {
  int? selectedNet;
  int? selectedGroup;

  void _showDynamicSelector(String label, List<int> options, int? currentValue, Function(int?) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF353C3F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Select $label", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Always show the "All" option
                  ListTile(
                    title: const Text("* (Show All)", style: TextStyle(color: Color(0xFFE16D00), fontWeight: FontWeight.bold)),
                    leading: const Icon(Icons.all_inclusive, color: Color(0xFFE16D00)),
                    onTap: () { onSelect(null); Navigator.pop(context); },
                  ),
                  const Divider(height: 1),
                  // Show only what exists in the manager
                  ...options.map((val) => ListTile(
                    title: Text("$label $val"),
                    selected: currentValue == val,
                    selectedTileColor: Colors.white10,
                    trailing: currentValue == val ? const Icon(Icons.check, color: Color(0xFFE16D00)) : null,
                    onTap: () { onSelect(val); Navigator.pop(context); },
                  )),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manager = Provider.of<ObjectManager>(context);

    // Extract unique IDs for the filter bar
    final availableNets = manager.objects.map((e) => e.id.net).toSet().toList()..sort();
    final availableGroups = manager.objects
        .where((e) => selectedNet == null || e.id.net == selectedNet)
        .map((e) => e.id.group).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Registry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save All Changes',
            onPressed: () => manager.saveAll(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create new object',
            onPressed: () => showNewObjectDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Reload everything',
            onPressed: () => manager.reloadObjects(),
          ),
          IconButton(
            icon: const Icon(Icons.deselect_outlined),
            tooltip: 'Format memory',
            onPressed: () => showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Format Memory?'),
                  content: const Text(
                    'This will permanently erase all stored data.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Format'),
                      onPressed: () {
                        manager.format();
                        Navigator.of(context).pop();

                        // Optional: Show a snackbar confirmation
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Memory formatted')),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            height: 50,
            child: Row(
              children: [
                _buildHeaderBtn("NET", selectedNet, () =>
                    _showDynamicSelector("NET", availableNets, selectedNet, (v) => setState(() => selectedNet = v))),
                const VerticalDivider(width: 1),
                _buildHeaderBtn("GROUP", selectedGroup, () =>
                    _showDynamicSelector("GROUP", availableGroups, selectedGroup, (v) => setState(() => selectedGroup = v))),
              ],
            ),
          ),

          // The List
          Expanded(
            child: Consumer<ObjectManager>(
              builder: (context, manager, child) {
                final filteredList = manager.objects.where((obj) {
                  return (selectedNet == null || obj.id.net == selectedNet) &&
                      (selectedGroup == null || obj.id.group == selectedGroup);
                }).toList();

                if (filteredList.isEmpty) {
                  return const Center(child: Text('No objects found in this scope.'));
                }

                return ListView.separated(
                  itemCount: filteredList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
                  itemBuilder: (context, index) => _buildObjectTile(context, filteredList[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBtn(String label, int? value, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("$label ", style: const TextStyle(fontSize: 12, color: Colors.white54)),
            Text(
              value?.toString() ?? "*",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: value == null ? Colors.white : const Color(0xFFE16D00)
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  // Refactored your ListTile for cleaner code
  Widget _buildObjectTile(BuildContext context, NodeObject object) {
    final theme = Theme.of(context);
    final bool isInactive = object.info.flags.has(Flags.inactive);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isInactive ? Colors.white10 : theme.colorScheme.primaryContainer,
        child: Icon(
          getIconForType(object.type),
          color: isInactive ? Colors.white24 : theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        object.name,
        style: TextStyle(
          color: isInactive ? Colors.white38 : Colors.white,
          decoration: isInactive ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Row(
        children: [
          Text(object.id.fullAddress, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          const SizedBox(width: 8),
          if (object.info.flags.has(Flags.auto))
            const Icon(Icons.hdr_auto_outlined, size: 12, color: Colors.grey),
          if (object.info.flags.has(Flags.dirty))
            const Icon(Icons.save_as_outlined, size: 12, color: Colors.orangeAccent),
        ],
      ),
      trailing: _buildTrailing(object),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ObjectPage(object: object))
      ),
    );
  }

  Widget? _buildTrailing(NodeObject object) {
    // If it's a program, show specialized play/stop buttons
    // Otherwise, just a simple chevron
    return (object.type == ObjectTypes.Program)
        ? _buildProgramControls(object)
        : const Icon(Icons.chevron_right, color: Colors.white10);
  }

  Widget _buildProgramControls(NodeObject object) {
    // Check if the program is currently active in any running state
    final bool isRunningOnce = object.info.flags.has(Flags.runOnce);
    final bool isRunningLoop = object.info.flags.has(Flags.runLoop);
    final bool isAnyRunning = isRunningOnce || isRunningLoop;

    if (isAnyRunning) {
      // Show a single Stop button if any execution is active
      return IconButton(
        icon: const Icon(Icons.stop_circle_outlined),
        color: Colors.redAccent,
        tooltip: "Stop Program",
        onPressed: () {
          final newFlags = FlagClass(object.info.flags.value);
          newFlags.remove(Flags.runOnce);
          newFlags.remove(Flags.runLoop);
          _sendInfoUpdate(object, newFlags);
        },
      );
    }

    // Show two distinct play buttons if idle
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.looks_one_outlined),
          color: Colors.blueAccent,
          tooltip: "Run Once",
          onPressed: () {
            final newFlags = FlagClass(object.info.flags.value);
            newFlags.add(Flags.runOnce);
            _sendInfoUpdate(object, newFlags);
          },
        ),
        IconButton(
          icon: const Icon(Icons.cached_outlined),
          color: Colors.greenAccent,
          tooltip: "Run Loop",
          onPressed: () {
            final newFlags = FlagClass(object.info.flags.value);
            newFlags.add(Flags.runLoop);
            _sendInfoUpdate(object, newFlags);
          },
        ),
      ],
    );
  }

  void _sendInfoUpdate(NodeObject object, FlagClass newFlags) {
    // Atomic update including the existing period and phase
    final newInfo = ObjectInfo(
      flags: newFlags,
      runPeriod: object.info.runPeriod,
      runPhase: object.info.runPhase, // Added phase support
    );
    ObjectManager().writeInfo(object.id, newInfo);
  }
}