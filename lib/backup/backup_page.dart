import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../object/object_manager.dart';
import '../object/object.dart';
import '../types.dart';
import '../info.dart';
import 'jsonencode.dart';

enum ConflictStatus {
  newObject,
  identical,
  typeMatch,
  typeMismatched,
  autoTypeLocked,
  autoMoveLocked // NEW: Cannot remap address of Auto objects
}
enum BackupMode { backup, restore }

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  BackupMode _mode = BackupMode.backup;
  final Set<String> _selectedObjectIds = {};
  List<dynamic> _importList = [];
  Map<int, String> _idRemaps = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedObjectIds.contains(id)) _selectedObjectIds.remove(id);
      else _selectedObjectIds.add(id);
    });
  }

  /// Helper to compare Flags while ignoring the 'dirty' bit
  bool _areFlagsEqual(dynamic incomingFlags, dynamic localFlags) {
    // Assuming flags are handled as strings/lists from valueToJson
    if (incomingFlags is List && localFlags is List) {
      final Set<String> s1 = Set.from(incomingFlags)..remove('dirty');
      final Set<String> s2 = Set.from(localFlags)..remove('dirty');
      return s1.length == s2.length && s1.containsAll(s2);
    }
    return jsonEncode(incomingFlags) == jsonEncode(localFlags);
  }

  ConflictStatus _checkConflict(Map<String, dynamic> importData, String targetId) {
    final objectManager = context.read<ObjectManager>();

    // 1. RULE: A backed-up 'auto' object cannot be moved to a different address
    final List<dynamic> incomingFlags = importData['info']?['flags'] ?? [];
    if (incomingFlags.contains('auto') && importData['id'] != targetId) {
      return ConflictStatus.autoMoveLocked;
    }

    final existing = objectManager.objects.cast<NodeObject?>().firstWhere(
          (obj) => obj?.id.globalAddress == targetId, orElse: () => null,
    );

    if (existing == null) return ConflictStatus.newObject;

    // 2. RULE: Existing objects with 'auto' flag cannot have their type changed
    bool isAuto = existing.info.flags.has(Flags.auto);
    if (existing.type.name != importData['type']) {
      return isAuto ? ConflictStatus.autoTypeLocked : ConflictStatus.typeMismatched;
    }

    // Compare System Config (Ignoring Dirty Flag)
    final localInfoJson = valueToJson(Types.ObjectInfo, existing.info);
    bool infoMatch = existing.name == importData['name'] &&
        _areFlagsEqual(importData['info']['flags'], localInfoJson['flags']) &&
        importData['info']['runPeriod'] == localInfoJson['runPeriod'] &&
        importData['info']['runPhase'] == localInfoJson['runPhase'];

    if (!infoMatch) return ConflictStatus.typeMatch;

    // Compare values (Only those present in backup, ignoring ReadOnly)
    final List<dynamic> importValues = importData['values'] ?? [];
    for (var v in importValues) {
      final pathStr = v['path'];
      final localEntry = existing.values[pathStr];

      if (localEntry == null || localEntry.isReadOnly) continue;

      final localJson = valueToJson(localEntry.type, localEntry.data);
      if (jsonEncode(localJson) != jsonEncode(v['data'])) {
        return ConflictStatus.typeMatch;
      }
    }
    return ConflictStatus.identical;
  }

  bool get _canExport {
    // If you want to forbid backup during restore mode if errors exist:
    if (_mode == BackupMode.restore) {
      return !_importList.any((item) {
        int idx = _importList.indexOf(item);
        var status = _checkConflict(item, _idRemaps[idx]!);
        return status == ConflictStatus.autoMoveLocked || status == ConflictStatus.autoTypeLocked;
      });
    }
    return _selectedObjectIds.isNotEmpty;
  }
  // --- UI Builders ---

  Future<void> _handleSaveToFile() async {
    final objectManager = context.read<ObjectManager>();

    // 1. Filter only selected objects
    final selectedObjects = objectManager.objects
        .where((obj) => _selectedObjectIds.contains(obj.id.globalAddress))
        .map((obj) => obj.toBackupJson())
        .toList();

    if (selectedObjects.isEmpty) return;

    final backupData = {
      "version": "1.0",
      "timestamp": DateTime.now().toIso8601String(),
      "objects": selectedObjects,
    };

    // 2. Open Save Dialog
    String? outputPath = await FilePicker.saveFile(
      dialogTitle: 'Save Backup JSON',
      fileName: 'mcu_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputPath != null) {
      final file = File(outputPath);

      // PRETTY PRINTING LOGIC HERE:
      // Using 2 spaces for indentation
      const encoder = JsonEncoder.withIndent('  ');
      final prettyJson = encoder.convert(backupData);

      await file.writeAsString(prettyJson);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Backup saved to: ${file.path}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final objectManager = context.watch<ObjectManager>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Management"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SegmentedButton<BackupMode>(
              segments: const [
                ButtonSegment(value: BackupMode.backup, label: Text("Backup"), icon: Icon(Icons.download)),
                ButtonSegment(value: BackupMode.restore, label: Text("Restore"), icon: Icon(Icons.upload)),
              ],
              selected: {_mode},
              onSelectionChanged: (set) => setState(() {
                _mode = set.first;
                _selectedObjectIds.clear();
              }),
            ),
          ),
        ],
      ),
      body: _mode == BackupMode.backup
          ? _buildBackupList(objectManager.objects)
          : _buildRestoreList(theme),
      // UPDATED: Now shows different footers based on mode
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  Widget? _buildBottomBar(ThemeData theme) {
    if (_mode == BackupMode.backup && _selectedObjectIds.isNotEmpty) {
      return _buildBackupFooter(theme);
    }
    if (_mode == BackupMode.restore && _importList.isNotEmpty) {
      return _buildRestoreFooter(theme);
    }
    return null;
  }

  Widget _buildBackupFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
          ),
          onPressed: _handleSaveToFile,
          icon: const Icon(Icons.save),
          label: Text("SAVE ${_selectedObjectIds.length} OBJECTS TO FILE"),
        ),
      ),
    );
  }

  Widget _buildRestoreFooter(ThemeData theme) {
    final bool canRestore = _canExport; // Uses your logic to check for Auto flag errors

    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!canRestore)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  "Restore blocked: Resolve Auto-object conflicts.",
                  style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: canRestore ? theme.colorScheme.primary : theme.colorScheme.errorContainer,
                foregroundColor: canRestore ? theme.colorScheme.onPrimary : theme.colorScheme.onErrorContainer,
              ),
              // Disable button if canRestore is false
              onPressed: (canRestore && _selectedObjectIds.isNotEmpty) ? _startRestoreProcess : null,
              icon: Icon(canRestore ? Icons.cloud_upload : Icons.block),
              label: Text(canRestore
                  ? "RESTORE ${_selectedObjectIds.length} SELECTED"
                  : "FIX ERRORS TO RESTORE"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreList(ThemeData theme) {
    if (_importList.isEmpty) return Center(child: ElevatedButton(onPressed: _handleLoadFile, child: const Text("Load Backup File")));
    return Column(
      children: [
        _buildRestoreHeader(theme),
        Expanded(child: ListView.builder(itemCount: _importList.length, itemBuilder: (context, index) => _buildRestoreItem(index, _importList[index], theme))),
      ],
    );
  }

  Widget _buildRestoreItem(int index, Map<String, dynamic> item, ThemeData theme) {
    final String originalId = item['id'];
    final String targetId = _idRemaps[index]!;
    final bool isSelected = _selectedObjectIds.contains(originalId);
    final status = _checkConflict(item, targetId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(originalId)),
        title: Text("${item['name']} [${item['type']}]",
            style: TextStyle(decoration: isSelected ? null : TextDecoration.lineThrough)),
        subtitle: Row(
          children: [
            _getStatusIcon(status),
            const SizedBox(width: 8),
            Text("Target: $targetId", style: theme.textTheme.bodySmall),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: targetId,
                  decoration: const InputDecoration(labelText: "Target Address", border: OutlineInputBorder(), isDense: true),
                  onChanged: (val) => setState(() => _idRemaps[index] = val),
                ),
                const SizedBox(height: 16),
                _buildSystemConfigComparison(item, targetId, theme),
                const SizedBox(height: 16),
                const Text("Writable Parameters (from Backup):", style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                _buildValueComparison(item, targetId, theme),

                if (status == ConflictStatus.typeMismatched)
                  _buildWarningBanner("Type Mismatch: Existing object at $targetId will be redefined."),
                if (status == ConflictStatus.autoTypeLocked)
                  _buildWarningBanner("LOCKED: Object at $targetId is 'Auto' and cannot change types. Restore may fail."),
                if (status == ConflictStatus.autoMoveLocked)
                  _buildWarningBanner("FORBIDDEN: Objects flagged as 'Auto' in the backup cannot be moved to a different address."),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSystemConfigComparison(Map<String, dynamic> item, String targetId, ThemeData theme) {
    final existing = context.read<ObjectManager>().objects.cast<NodeObject?>().firstWhere(
            (obj) => obj?.id.globalAddress == targetId, orElse: () => null
    );

    final incomingInfo = item['info'];
    final currentInfo = existing != null ? valueToJson(Types.ObjectInfo, existing.info) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("System Configuration:", style: TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        _diffRow("Name", item['name'], existing?.name, theme),
        _diffRow("Type", item['type'], existing?.type.name, theme),
        // Filter dirty flag from UI view
        _diffRow("Flags",
            (incomingInfo['flags'] as List)..remove('dirty'),
            (currentInfo?['flags'] as List?)?..remove('dirty'),
            theme),
        _diffRow("Timing", "P:${incomingInfo['runPeriod']} Ph:${incomingInfo['runPhase']}",
            existing != null ? "P:${existing.info.runPeriod} Ph:${existing.info.runPhase}" : null, theme),
      ],
    );
  }

  Widget _buildValueComparison(Map<String, dynamic> item, String targetId, ThemeData theme) {
    final List<dynamic> importValues = item['values'] ?? [];
    final objectManager = context.read<ObjectManager>();
    final existing = objectManager.objects.cast<NodeObject?>().firstWhere(
            (obj) => obj?.id.globalAddress == targetId, orElse: () => null
    );

    // Track which paths we've already displayed from the backup
    final Set<String> pathsDisplayed = {};

    return Column(
      children: [
        // 1. Process all values present in the BACKUP
        ...importValues.map((v) {
          final pathStr = v['path'];
          pathsDisplayed.add(pathStr);
          final localEntry = existing?.values[pathStr];

          if (localEntry != null && localEntry.isReadOnly) return const SizedBox.shrink();

          dynamic localValJson;
          if (localEntry != null) {
            localValJson = valueToJson(localEntry.type, localEntry.data);
          }

          return _diffRow("$pathStr (${v['type']})", v['data'], localValJson, theme);
        }),

        // 2. Process values that exist LIVE but are NOT in the backup
        if (existing != null)
          ...existing.values.entries.where((e) => !pathsDisplayed.contains(e.key)).map((e) {
            final localEntry = e.value;
            if (localEntry.isReadOnly) return const SizedBox.shrink();

            final localValJson = valueToJson(localEntry.type, localEntry.data);

            // Render as a "Keep" row: Incoming is null (or "Not in Backup"), Current is displayed
            return _diffRow(
              "${e.key} (${localEntry.type.name})",
              "---", // Visual indicator that backup doesn't touch this
              localValJson,
              theme,
              isOrphan: true,
            );
          }),
      ],
    );
  }

  Widget _diffRow(String label, dynamic incoming, dynamic current, ThemeData theme, {bool isOrphan = false}) {
    // If it's an orphan, it's not "different" in a conflict sense, but it is unique to the device
    final bool isDifferent = !isOrphan && (jsonEncode(incoming) != jsonEncode(current));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      decoration: BoxDecoration(
          color: isOrphan
              ? Colors.blueGrey.withOpacity(0.05) // Subtle gray for local-only data
              : (isDifferent ? Colors.amber.withOpacity(0.08) : null),
          borderRadius: BorderRadius.circular(4)
      ),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text(label, style: TextStyle(fontSize: 11, color: isOrphan ? Colors.blueGrey : Colors.grey))
          ),
          Expanded(
            child: Text(
                isOrphan ? "(Not in Backup)" : incoming.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isDifferent ? FontWeight.bold : FontWeight.normal,
                  color: isOrphan ? Colors.blueGrey : (isDifferent ? Colors.amber[900] : null),
                  fontStyle: isOrphan ? FontStyle.italic : FontStyle.normal,
                )
            ),
          ),
          if (current != null)
            Expanded(
              child: Text(
                  " [Live: ${current.toString()}]",
                  style: TextStyle(
                      fontSize: 11,
                      color: isOrphan ? theme.colorScheme.primary.withOpacity(0.7) : Colors.blueGrey.withOpacity(0.6),
                      fontStyle: FontStyle.italic
                  )
              ),
            ),
          Icon(
              isOrphan ? Icons.visibility_outlined : (isDifferent ? Icons.edit_note : Icons.check),
              size: 14,
              color: isOrphan ? Colors.blueGrey : (isDifferent ? Colors.amber : Colors.green)
          ),
        ],
      ),
    );
  }

  // --- Common Logic ---

  void _handleLoadFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result != null && result.files.single.path != null) {
      final data = jsonDecode(await File(result.files.single.path!).readAsString());
      setState(() {
        _importList = data['objects'] ?? [];
        _idRemaps.clear();
        _selectedObjectIds.clear();
        for (int i = 0; i < _importList.length; i++) {
          _idRemaps[i] = _importList[i]['id'];
          _selectedObjectIds.add(_importList[i]['id']);
        }
        _mode = BackupMode.restore;
      });
    }
  }

  Future<void> _startRestoreProcess() async {
    final objectManager = context.read<ObjectManager>();
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator())
    );

    try {
      for (int i = 0; i < _importList.length; i++) {
        final objData = _importList[i];
        if (!_selectedObjectIds.contains(objData['id'])) continue;

        final targetRef = Reference.parse(_idRemaps[i]!);
        final existing = objectManager.objects.cast<NodeObject?>().firstWhere(
                (o) => o?.id.globalAddress == targetRef.globalAddress,
            orElse: () => null
        );

        // 1. Handle Type Mismatch
        if (existing != null && existing.type.name != objData['type']) {
          if (existing.info.flags.has(Flags.auto)) continue;
          objectManager.deleteObject(targetRef);
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // 2. Create Object shell (No Info yet)
        final incomingType = ObjectTypes.values.firstWhere(
                (e) => e.name == objData['type'],
            orElse: () => ObjectTypes.Undefined
        );

        objectManager.createObject(targetRef, incomingType);
        await Future.delayed(const Duration(milliseconds: 100));

        // NEW: Set the Object Name
        // Assuming 'name' exists at the top level of your objData JSON
        if (objData['name'] != null) {
          objectManager.writeName(targetRef, objData['name']);
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // 3. Process Values FIRST
        final List<dynamic> importValues = objData['values'] ?? [];
        final Set<String> incomingPaths = importValues.map((v) => v['path'] as String).toSet();

        // A. DELETE local orphans
        if (existing != null) {
          for (var pathKey in existing.values.keys) {
            if (!incomingPaths.contains(pathKey)) {
              final deleteRef = Reference(targetRef.net, targetRef.group, targetRef.device, Path.fromString(pathKey));
              objectManager.deleteValue(deleteRef);
              await Future.delayed(const Duration(milliseconds: 100));
            }
          }
        }

        // B. WRITE values from backup (Population Phase)
        for (var v in importValues) {
          final dType = Types.values.firstWhere((e) => e.name == v['type'], orElse: () => Types.Byte);
          final valRef = Reference(targetRef.net, targetRef.group, targetRef.device, Path.fromString(v['path']));
          final decodedData = valueFromJson(dType, v['data']);

          objectManager.writeValue(valRef, decodedData, type: dType);
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // 4. SET INFO LAST (Activation Phase)
        // This sets the flags (like Auto) and metadata AFTER the values are in place.
        objectManager.writeInfo(targetRef, valueFromJson(Types.ObjectInfo, objData['info']));
        await Future.delayed(const Duration(milliseconds: 100));

        objectManager.refreshObject(targetRef);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Restore Complete: Sync successful")));
    } catch (e) {
      print("Restore Error: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildBackupList(List<NodeObject> objects) {
    if (objects.isEmpty) return const Center(child: Text("No live objects found."));
    return ListView.builder(
      itemCount: objects.length,
      itemBuilder: (context, index) {
        final obj = objects[index];
        return CheckboxListTile(
          title: Text(obj.name),
          subtitle: Text("${obj.id.globalAddress} [${obj.type.name}]"),
          value: _selectedObjectIds.contains(obj.id.globalAddress),
          onChanged: (_) => _toggleSelection(obj.id.globalAddress),
        );
      },
    );
  }

  Widget _getStatusIcon(ConflictStatus s) {
    switch (s) {
      case ConflictStatus.newObject: return const Icon(Icons.add_circle_outline, color: Colors.green, size: 18);
      case ConflictStatus.identical: return const Icon(Icons.check_circle, color: Colors.blue, size: 18);
      case ConflictStatus.typeMatch: return const Icon(Icons.sync, color: Colors.orange, size: 18);
      case ConflictStatus.typeMismatched: return const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18);
      case ConflictStatus.autoTypeLocked: return const Icon(Icons.lock_outline, color: Colors.purple, size: 18);
      case ConflictStatus.autoMoveLocked: return const Icon(Icons.not_listed_location, color: Colors.red, size: 18);
    }
  }

  Widget _buildRestoreHeader(ThemeData theme) {
    bool all = _selectedObjectIds.length == _importList.length;
    return Container(
      padding: const EdgeInsets.all(12),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Checkbox(value: all, tristate: _selectedObjectIds.isNotEmpty && !all, onChanged: (v) {
            setState(() {
              if (v == true) _selectedObjectIds.addAll(_importList.map((e) => e['id'] as String));
              else _selectedObjectIds.clear();
            });
          }),
          const Text("Select for Restore"),
          const Spacer(),
          Text("${_selectedObjectIds.length} objects queued"),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(String t) => Container(padding: const EdgeInsets.all(8), color: Colors.red.withOpacity(0.1), margin: const EdgeInsets.only(top: 8), child: Text(t, style: const TextStyle(color: Colors.red, fontSize: 11)));
}