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

    // 1. Extract unique IDs currently in the list
    final availableNets = manager.objects.map((e) => e.id.net).toSet().toList()..sort();

    // For Groups, we only show groups available within the currently selected NET (unless NET is *)
    final availableGroups = manager.objects
        .where((e) => selectedNet == null || e.id.net == selectedNet)
        .map((e) => e.id.group).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Object List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Create New Object",
            onPressed: () {
              showNewObjectDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Reload Registry",
            onPressed: () {
              manager.reloadObjects();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Syncing object registry..."),
                  duration: Duration(milliseconds: 800),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- DYNAMIC SELECTOR BAR ---
          Container(
            color: theme.colorScheme.secondary.withOpacity(0.5),
            height: 50,
            child: Row(
              children: [
                _buildHeaderBtn("NET", selectedNet, () =>
                    _showDynamicSelector("NET", availableNets, selectedNet, (v) => setState(() => selectedNet = v))),
                VerticalDivider(color: Colors.white10, width: 1, indent: 10, endIndent: 10),
                _buildHeaderBtn("GROUP", selectedGroup, () =>
                    _showDynamicSelector("GROUP", availableGroups, selectedGroup, (v) => setState(() => selectedGroup = v))),
              ],
            ),
          ),

          // --- FILTERED LIST ---
          Expanded(
            child: Consumer<ObjectManager>(
              builder: (context, manager, child) {
                final filteredList = manager.objects.where((obj) {
                  final netMatch = selectedNet == null || obj.id.net == selectedNet;
                  final groupMatch = selectedGroup == null || obj.id.group == selectedGroup;
                  return netMatch && groupMatch;
                }).toList();

                if (filteredList.isEmpty) {
                  return const Center(child: Text('No objects found in this scope.'));
                }

                return ListView.builder(
                  itemCount: filteredList.length,
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
    return ListTile(
      leading: Icon(getIconForType(object.type)),
      title: Text(object.name),
      subtitle: Text('${object.id.fullAddress} - ${object.type.name}'),
      trailing: object.type == Types.Program ? _buildProgramControls(object) : null,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => ObjectPage(object: object))),
    );
  }

  Widget _buildProgramControls(NodeObject object) {
    bool isRunning = (object.flags.value & (Flags.runLoop.value | Flags.runOnce.value)) != 0;

    return isRunning
        ? IconButton(
      icon: const Icon(Icons.stop, color: Colors.redAccent),
      onPressed: () => _sendFlagUpdate(object, object.flags.value & ~(Flags.runLoop.value | Flags.runOnce.value)),
    )
        : Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.one_x_mobiledata_outlined),
          onPressed: () => _sendFlagUpdate(object, object.flags.value | Flags.runOnce.value),
        ),
        IconButton(
          icon: const Icon(Icons.play_arrow_outlined),
          onPressed: () => _sendFlagUpdate(object, object.flags.value | Flags.runLoop.value),
        ),
      ],
    );
  }

  void _sendFlagUpdate(NodeObject object, int newFlags) {
    Message message = Message();
    message.addSegment(Types.Function, Functions.SetFlags);
    message.addSegment(Types.Reference, object.id);
    message.addSegment(Types.Flags, FlagClass(newFlags));
    BluetoothManager().sendMessage(message);
  }
}