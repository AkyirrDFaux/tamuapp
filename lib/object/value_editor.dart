import 'dart:math';
import 'package:flutter/material.dart';
import '../types.dart';
import '../values.dart';
import 'object.dart';
import 'object_manager.dart';

class ValueEditor extends StatefulWidget {
  final Reference reference;
  final dynamic initialValue;
  final Types initialType;
  final Function(Types type, dynamic value) onApply;

  const ValueEditor({
    super.key,
    required this.reference,
    required this.initialValue,
    required this.initialType,
    required this.onApply,
  });

  // FIX: Ensure this returns void and correctly builds the widget instance
  static Future<void> show(
      BuildContext context,
      Reference ref,
      dynamic val,
      Types type,
      Function(Types, dynamic) onApply
      ) {
    return showDialog<void>(
      context: context,
      builder: (numContext) => ValueEditor( // 'ValueEditor' is the Constructor here
        reference: ref,
        initialValue: val,
        initialType: type,
        onApply: onApply,
      ),
    );
  }

  @override
  State<ValueEditor> createState() => _ValueEditorState();
}

class _ValueEditorState extends State<ValueEditor> {
  late Types selectedType;
  late dynamic currentValue;

  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType;
    // If null, start with a safe default for the initial type
    currentValue = widget.initialValue ?? _getDefaultValueForType(selectedType);
    _syncController();
  }

  // Simplest approach: Just reset to default on change
  void _onTypeChanged(Types? newType) {
    if (newType == null) return;
    setState(() {
      selectedType = newType;
      currentValue = _getDefaultValueForType(newType);
      _syncController();
    });
  }

  dynamic _getDefaultValueForType(Types type) {
    if (isInValueEnum(type)) return 0;

    switch (type) {
      case Types.PortNumber: return -1;
      case Types.Bool:      return false;
      case Types.Byte:      return 0;
      case Types.Integer:   return 0;
      case Types.Number:    return 0.0;
      case Types.Text:      return "";
      case Types.Colour:    return Colour(255, 255, 255, 255);
      case Types.Vector2D:  return Vector2D(0, 0);
      case Types.Vector3D:  return Vector3D(0, 0, 0);
      case Types.Coord2D:   return Coord2D(Vector2D(0, 0), Vector2D(1, 0));
      case Types.Coord3D:   return Coord3D(Vector3D(0, 0, 0), Vector3D(1, 0, 0));
      case Types.Reference: return Reference(0, 0, 0, Path([]));
      default:              return null;
    }
  }

  void _syncController() {
    // Ensure we don't treat 0 as null here
    if (currentValue == null) {
      _textController.text = "";
    } else {
      _textController.text = currentValue.toString();
    }
  }

  void _updateValue(dynamic newValue) {
    setState(() => currentValue = newValue);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("EDIT VALUE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38)),
          const SizedBox(height: 8),
          DropdownButtonFormField<Types>(
            value: selectedType,
            decoration: const InputDecoration(labelText: "Data Type", isDense: true, border: OutlineInputBorder()),
            items: Types.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
            onChanged: _onTypeChanged,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 300,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(selectedType), // Forces fresh widget when type changes
              child: _buildEditorForType(),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ElevatedButton(
          onPressed: () {
            widget.onApply(selectedType, currentValue);
            Navigator.pop(context);
          },
          child: const Text("APPLY"),
        ),
      ],
    );
  }

  Widget _buildEditorForType() {
    if (isInValueEnum(selectedType)) return _buildEnumEditor();

    switch (selectedType) {
      case Types.Bool:
        return SwitchListTile(
          title: const Text("Boolean State"),
          value: currentValue == true,
          onChanged: (v) => _updateValue(v),
        );

      case Types.PortNumber:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel("PORT INDEX"),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: "Port ID",
                hintText: "0-127 (or -1)",
                suffixText: "int8",
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              onChanged: (v) {
                int? parsed = int.tryParse(v);
                if (parsed != null) {
                  // Only allow positive values or exactly -1
                  if (parsed >= 0 || parsed == -1) {
                    _updateValue(parsed.clamp(-1, 127));
                  }
                }
              },
            ),
            const SizedBox(height: 4),
            const Text(
              "Valid range: 0 to 127. Use -1 for unassigned.",
              style: TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        );

      case Types.Byte:
      case Types.Integer:
        return TextField(
          controller: _textController,
          decoration: InputDecoration(
            labelText: selectedType == Types.Byte ? "Value (0-255)" : "Integer Value",
            suffixText: selectedType == Types.Byte ? "uint8" : "int32",
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            int parsed = int.tryParse(v) ?? 0;
            currentValue = selectedType == Types.Byte ? parsed.clamp(0, 255) : parsed;
          },
        );

      case Types.Number:
        return Column(
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(labelText: "Float Value"),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => currentValue = double.tryParse(v) ?? 0.0,
            ),
            Slider(
              value: (currentValue as num).toDouble().clamp(-1.0, 1.0),
              min: -1.0, max: 1.0,
              onChanged: (v) {
                _updateValue(v);
                _syncController();
              },
            ),
          ],
        );

      case Types.Vector2D:
        final v = currentValue as Vector2D? ?? Vector2D(0, 0);
        return _buildVector2DEditor(v, (newV) => _updateValue(newV));

      case Types.Vector3D:
        final v = currentValue as Vector3D? ?? Vector3D(0, 0, 0);
        return _buildVector3DEditor(v, (newV) => _updateValue(newV));

      case Types.Coord2D:
        final c = currentValue as Coord2D? ?? Coord2D(Vector2D(0, 0), Vector2D(1, 0));
        return Column(
          children: [
            _sectionLabel("POSITION"),
            _buildVector2DEditor(c.Position, (v) => _updateValue(Coord2D(v, c.Rotation))),
            const Divider(color: Colors.white10),
            _sectionLabel("ROTATION (ANGULAR)"),
            _buildRotation2D(c.Rotation, (v) => _updateValue(Coord2D(c.Position, v))),
          ],
        );

      case Types.Coord3D:
        final c = currentValue as Coord3D? ?? Coord3D(Vector3D(0, 0, 0), Vector3D(1, 0, 0));
        return Column(
          children: [
            _sectionLabel("POSITION"),
            _buildVector3DEditor(c.Position, (v) => _updateValue(Coord3D(v, c.Rotation))),
            const Divider(color: Colors.white10),
            _sectionLabel("ROTATION (PITCH/YAW)"),
            _buildRotation3D(c.Rotation, (v) => _updateValue(Coord3D(c.Position, v))),
          ],
        );

      case Types.Colour:
        return _buildColourEditor();

      case Types.Text:
        return TextField(
          controller: _textController,
          maxLines: 5,
          decoration: const InputDecoration(hintText: "Enter string data...", border: OutlineInputBorder()),
          onChanged: (v) => currentValue = v,
        );

      case Types.Reference:
        final r = currentValue as Reference? ?? Reference(0, 0, 0, Path([]));
        return _buildReferenceEditor(r, (newRef) => _updateValue(newRef));

      default:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text("No or binary Data",
                style: const TextStyle(color: Colors.white24, fontSize: 12)),
          ),
        );
    }
  }

  Widget _buildEnumEditor() {
    final theme = Theme.of(context);
    final Map<int, String>? options = getValueEnumMap(selectedType);

    if (options == null || options.isEmpty) {
      return const Text("Error: No mapping data found.");
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: ListView(
        shrinkWrap: true,
        children: options.entries.map((e) {
          // FIX: Explicitly check for null. 0 is a valid value and should not be treated as null.
          final isSelected = (currentValue != null && currentValue == e.key);

          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: RadioListTile<int>(
              title: Text(
                e.value,
                style: TextStyle(
                  color: isSelected ? theme.colorScheme.primary : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              value: e.key,
              // FIX: groupValue must be nullable int or handle 0 explicitly
              groupValue: currentValue is int ? currentValue as int : null,
              activeColor: theme.colorScheme.primary,
              onChanged: (val) {
                if (val != null) _updateValue(val);
              },
              controlAffinity: ListTileControlAffinity.trailing,
              dense: true,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSlider(String label, int val, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 20, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          Expanded(
            child: Slider(
              value: val.toDouble(),
              min: 0,
              max: 255,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 45,
            child: TextField(
              controller: TextEditingController(text: val.toString())..selection = TextSelection.collapsed(offset: val.toString().length),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(4), border: OutlineInputBorder()),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null) onChanged(parsed.toDouble().clamp(0, 255));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 1.2)),
    );
  }

  Widget _buildVector2DEditor(Vector2D v, Function(Vector2D) onUpdate) {
    return _buildMultiNumericEditor(
        ['X', 'Y'],
        [v.X, v.Y],
            (vals) => onUpdate(Vector2D(vals[0], vals[1]))
    );
  }

  Widget _buildRotation2D(Vector2D v, Function(Vector2D) onUpdate) {
    // Convert Vector to Degrees: atan2 returns radians
    double degrees = atan2(v.Y, v.X) * 180 / pi;

    return Row(
      children: [
        Expanded(
          child: Slider(
            value: degrees.clamp(-180.0, 180.0),
            min: -180, max: 180,
            onChanged: (deg) {
              double rad = deg * pi / 180;
              onUpdate(Vector2D(cos(rad), sin(rad)));
            },
          ),
        ),
        _buildNumericBox("DEGREES", degrees, (deg) {
          double rad = deg * pi / 180;
          onUpdate(Vector2D(cos(rad), sin(rad)));
        }),
      ],
    );
  }

  Widget _buildVector3DEditor(Vector3D v, Function(Vector3D) onUpdate) {
    return _buildMultiNumericEditor(
        ['X', 'Y', 'Z'],
        [v.X, v.Y, v.Z],
            (vals) => onUpdate(Vector3D(vals[0], vals[1], vals[2]))
    );
  }

  Widget _buildRotation3D(Vector3D v, Function(Vector3D) onUpdate) {
    // Calculate Pitch and Yaw from direction vector
    // Yaw = atan2(y, x)
    // Pitch = atan2(z, sqrt(x^2 + y^2))
    double yaw = atan2(v.Y, v.X) * 180 / pi;
    double pitch = atan2(v.Z, sqrt(v.X * v.X + v.Y * v.Y)) * 180 / pi;

    return Column(
      children: [
        Row(
          children: [
            _buildNumericBox("PITCH", pitch, (p) => _updateRotation3D(p, yaw, onUpdate)),
            const SizedBox(width: 8),
            _buildNumericBox("YAW", yaw, (y) => _updateRotation3D(pitch, y, onUpdate)),
          ],
        ),
        const Text("Note: Vector direction implies rotation. Roll requires a second vector.",
            style: TextStyle(fontSize: 8, color: Colors.white12)),
      ],
    );
  }

  void _updateRotation3D(double pDeg, double yDeg, Function(Vector3D) onUpdate) {
    double pRad = pDeg * pi / 180;
    double yRad = yDeg * pi / 180;

    // Standard Spherical to Cartesian conversion
    double x = cos(pRad) * cos(yRad);
    double y = cos(pRad) * sin(yRad);
    double z = sin(pRad);

    onUpdate(Vector3D(x, y, z));
  }

  Widget _buildMultiNumericEditor(List<String> labels, List<double> values, Function(List<double>) onUpdate) {
    return Row(
      children: List.generate(labels.length, (i) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labels[i], style: const TextStyle(fontSize: 10, color: Colors.white38)),
                const SizedBox(height: 4),
                TextField(
                  // Key allows the field to rebuild correctly if the object is swapped
                  key: ValueKey("${labels[i]}_${values[i]}"),
                  controller: TextEditingController(text: values[i].toStringAsFixed(3))
                    ..selection = TextSelection.collapsed(offset: values[i].toStringAsFixed(3).length),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(8),
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) {
                      values[i] = parsed;
                      onUpdate(values);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumericBox(String label, double val, Function(double) onUpdate) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: val.toStringAsFixed(3)),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null) onUpdate(parsed);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColourEditor() {
    // Safe cast for new nodes
    final c = currentValue is Colour ? currentValue as Colour : Colour(255, 255, 255, 255);

    return Column(
      children: [
        // Large Preview Area
        Container(
          height: 50,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: Color.fromARGB(c.A, c.R, c.G, c.B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Color.fromARGB(c.A, c.R, c.G, c.B).withOpacity(0.5),
                  blurRadius: 10,
                )
              ]
          ),
          child: Center(
            child: Text(
              "#${c.R.toRadixString(16).padLeft(2, '0')}${c.G.toRadixString(16).padLeft(2, '0')}${c.B.toRadixString(16).padLeft(2, '0')}".toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, shadows: [Shadow(blurRadius: 2)]),
            ),
          ),
        ),

        _buildSlider("R", c.R, (v) => _updateValue(Colour(v.toInt(), c.G, c.B, c.A))),
        _buildSlider("G", c.G, (v) => _updateValue(Colour(c.R, v.toInt(), c.B, c.A))),
        _buildSlider("B", c.B, (v) => _updateValue(Colour(c.R, c.G, v.toInt(), c.A))),
        _buildSlider("A", c.A, (v) => _updateValue(Colour(c.R, c.G, c.B, v.toInt()))),
      ],
    );
  }

  int _refEditMode = 0; // 0 for Link, 1 for Manual

  Widget _buildReferenceEditor(Reference r, Function(Reference) onUpdate) {
    final theme = Theme.of(context);
    final List<NodeObject> availableObjects = ObjectManager().objects;

    // Use isGlobal from the actual reference to set initial toggle state
    // only if we haven't manually toggled it in this session yet.
    _refEditMode = r.isGlobal ? 0 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("REFERENCE TYPE"),
        Center(
          child: ToggleButtons(
            isSelected: [_refEditMode == 0, _refEditMode == 1],
            onPressed: (index) {
              setState(() {
                _refEditMode = index;
                // Transition between Global and Local
                if (index == 0) {
                  onUpdate(Reference(0, 0, 0, r.location)); // Switch to Global
                } else {
                  onUpdate(Reference.local(r.location));    // Switch to Local
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 120),
            selectedColor: theme.colorScheme.onPrimary,
            fillColor: _refEditMode == 0 ? theme.colorScheme.tertiary : theme.colorScheme.primary,
            children: const [
              Text("GLOBAL LINK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Text("LOCAL PATH", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Address Input (Only for Global)
        if (_refEditMode == 0) ...[
          _sectionLabel("TARGET OBJECT (NET.GP.DEV)"),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            value: availableObjects.any((obj) =>
            obj.id.net == r.net && obj.id.group == r.group && obj.id.device == r.device)
                ? "${r.net}.${r.group}.${r.device}"
                : null,
            items: availableObjects.map((obj) {
              final addr = "${obj.id.net}.${obj.id.group}.${obj.id.device}";
              return DropdownMenuItem(
                value: addr,
                child: Text("${obj.name} ($addr)", style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (addr) {
              if (addr != null) {
                final p = addr.split('.').map(int.parse).toList();
                onUpdate(Reference(p[0], p[1], p[2], r.location));
              }
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildByteField("NET", r.net, (v) => onUpdate(Reference(v, r.group, r.device, r.location)))),
              const SizedBox(width: 8),
              Expanded(child: _buildByteField("GP", r.group, (v) => onUpdate(Reference(r.net, v, r.device, r.location)))),
              const SizedBox(width: 8),
              Expanded(child: _buildByteField("DEV", r.device, (v) => onUpdate(Reference(r.net, r.group, v, r.location)))),
            ],
          ),
        ] else ...[
          // Local Mode visual feedback
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.white38),
                SizedBox(width: 8),
                Text("Pointing to a relative path in this device.", style: TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
        ],

        const Divider(height: 32, color: Colors.white10),

        // 3. Sub-Path Editor
        _sectionLabel("SUB-VALUE PATH"),
        _buildPathSegmentList(r.location, (newPath) {
          if (r.isGlobal) {
            onUpdate(Reference(r.net, r.group, r.device, newPath));
          } else {
            onUpdate(Reference.local(newPath));
          }
        }),

        // Visual Preview of the full address string
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            "RESULT: ${r.fullAddress}",
            style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: theme.colorScheme.secondary.withOpacity(0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildPathSegmentList(Path p, Function(Path) onUpdate) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          if (p.indices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Root (Empty Path)", style: TextStyle(color: Colors.white24, fontSize: 12)),
            ),

          ...p.indices.asMap().entries.map((entry) {
            final index = entry.key;
            final val = entry.value;

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Text("$index:", style: const TextStyle(fontFamily: 'monospace', color: Colors.white24, fontSize: 12)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      key: ValueKey("segment_${index}_$val"),
                      // Use selection collapsed to keep cursor at end during rebuilds
                      controller: TextEditingController(text: val.toString())
                        ..selection = TextSelection.collapsed(offset: val.toString().length),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null) {
                          List<int> next = List.from(p.indices);
                          next[index] = parsed.clamp(0, 255);
                          // Trigger the update immediately on every keystroke
                          onUpdate(Path(next));
                        }
                      },
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
                    onPressed: () {
                      List<int> next = List.from(p.indices)..removeAt(index);
                      onUpdate(Path(next));
                    },
                  )
                ],
              ),
            );
          }),

          const Divider(height: 20, indent: 12, endIndent: 12),
          TextButton.icon(
            onPressed: () {
              List<int> next = List.from(p.indices)..add(0);
              onUpdate(Path(next));
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text("ADD SEGMENT"),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // Simplified Byte Field - No Expanded inside!
  Widget _buildByteField(String label, int val, Function(int) onUpdate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38)),
        if (label.isNotEmpty) const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: val.toString())
            ..selection = TextSelection.collapsed(offset: val.toString().length),
          keyboardType: TextInputType.number,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            final parsed = int.tryParse(v);
            if (parsed != null) onUpdate(parsed.clamp(0, 255));
          },
        ),
      ],
    );
  }
}