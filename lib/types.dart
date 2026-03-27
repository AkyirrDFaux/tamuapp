import 'package:flutter/material.dart';

enum Types {
  Undefined(0),
  Bool(1),
  Byte(2),
  Type(3),
  ObjectType(4),
  ObjectInfo(5),
  Status(6),
  Board(7),
  Sensor(8),
  PortDriver(9),
  I2CDevice(10),
  Input(11),
  LEDStrip(12),
  Texture1D(13),
  Display(14),
  Geometry2D(15),
  GeometryOperation(16),
  Texture2D(17),
  Operation(18),
  Program(19),
  LocalFunction(20),
  Function(21),
  Group(22),
  Integer(23),
  Number(24),
  PortType(25),
  Pin(26),
  Colour(27),
  Vector2D(28),
  Vector3D(29),
  Coord2D(30),
  Coord3D(31),
  Text(32),
  Reference(33),
  Path(34),
  Message(35);

  final int value;
  const Types(this.value);

  static Types fromValue(int value) {
    return Types.values.firstWhere(
          (t) => t.value == value,
      orElse: () => Types.Undefined,
    );
  }
}

enum ObjectTypes {
  Undefined(0),
  Board(1),
  LEDStrip(2),
  Display(3),
  Input(4),
  Sensor(5),
  Output(6),
  Program(7),
  I2C(8),
  UART(9),
  SPI(10),
  OLED(11);

  final int value;
  const ObjectTypes(this.value);

  static ObjectTypes fromValue(int value) {
    return ObjectTypes.values.firstWhere(
          (t) => t.value == value,
      orElse: () => ObjectTypes.Undefined,
    );
  }
}

final Map<ObjectTypes, IconData> objectTypeIcons = {
  ObjectTypes.Undefined: Icons.help_outline,
  ObjectTypes.Board: Icons.memory_outlined,
  ObjectTypes.LEDStrip: Icons.wb_incandescent_outlined,
  ObjectTypes.Display: Icons.desktop_windows_outlined,
  ObjectTypes.Input: Icons.login_outlined,      // Specific "Input" feel
  ObjectTypes.Sensor: Icons.sensors,            // New: Matches SensorClass
  ObjectTypes.Output: Icons.logout_outlined,    // New: Logical counterpart to Input
  ObjectTypes.Program: Icons.terminal_outlined,
  ObjectTypes.I2C: Icons.account_tree_outlined,
  ObjectTypes.UART: Icons.settings_input_component,
  ObjectTypes.SPI: Icons.cable,
  ObjectTypes.OLED: Icons.tv_outlined,
};

final Map<Types, IconData> typeIcons = {
  Types.Undefined: Icons.help_outline,
  Types.Bool: Icons.toggle_on_outlined,
  Types.Byte: Icons.data_array,
  Types.Type: Icons.category,
  Types.ObjectType: Icons.sell_outlined,
  Types.ObjectInfo: Icons.flag_outlined,
  Types.Status: Icons.info_outline,
  Types.Board: Icons.memory_outlined,
  Types.Sensor: Icons.sensors, // New
  Types.PortDriver: Icons.tune_outlined,
  Types.I2CDevice: Icons.screen_rotation,
  Types.Input: Icons.input_outlined,
  Types.LEDStrip: Icons.wb_incandescent_outlined,
  Types.Texture1D: Icons.linear_scale_outlined,
  Types.Display: Icons.desktop_windows_outlined,
  Types.Geometry2D: Icons.square_foot_outlined,
  Types.GeometryOperation: Icons.gesture_outlined,
  Types.Texture2D: Icons.texture_outlined,
  Types.Operation: Icons.settings_outlined,
  Types.Program: Icons.terminal_outlined,
  Types.LocalFunction: Icons.code, // New
  Types.Function: Icons.functions_outlined,
  Types.Group: Icons.group_work, // New
  Types.Integer: Icons.pin_outlined,
  Types.Number: Icons.looks_one_outlined,
  Types.PortType: Icons.lan_outlined,
  Types.Pin: Icons.push_pin, // New
  Types.Colour: Icons.color_lens_outlined,
  Types.Vector2D: Icons.open_in_full_outlined,
  Types.Vector3D: Icons.navigation_outlined,
  Types.Coord2D: Icons.place_outlined,
  Types.Coord3D: Icons.threed_rotation,
  Types.Text: Icons.title_outlined,
  Types.Reference: Icons.tag_outlined,
  Types.Message: Icons.email, // New
};

// Example of how to use it:
IconData getIconForType(dynamic type) {
  if (type is Types) {
    return typeIcons[type] ?? Icons.device_unknown;
  } else if (type is ObjectTypes) {
    return objectTypeIcons[type] ?? Icons.device_unknown;
  }
  return Icons.device_unknown;
}
