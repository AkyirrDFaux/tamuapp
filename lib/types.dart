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
  AccGyr(10),
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
  Program(5),
  I2C(6),
  UART(7),
  SPI(8),
  OLED(9);

  final int value;
  const ObjectTypes(this.value);

  static ObjectTypes fromValue(int value) {
    for (var type in ObjectTypes.values) {
      if (type.value == value) {
        return type;
      }
    }
    return ObjectTypes.Undefined;
  }
}

final Map<ObjectTypes, IconData> objectTypeIcons = {
  ObjectTypes.Undefined: Icons.help_outline,
  //ObjectTypes.Shape2D: Icons.category_outlined,
  ObjectTypes.Board: Icons.memory_outlined,
  //ObjectTypes.Port: Icons.lan_outlined,
  //ObjectTypes.Fan: Icons.wind_power_outlined,
  ObjectTypes.LEDStrip: Icons.wb_incandescent_outlined,
  //ObjectTypes.LEDSegment: Icons.view_agenda_outlined,
  //ObjectTypes.Texture1D: Icons.linear_scale_outlined,
  ObjectTypes.Display: Icons.desktop_windows_outlined,
  //ObjectTypes.Geometry2D: Icons.square_foot_outlined,
  //ObjectTypes.Texture2D: Icons.texture_outlined,
  //ObjectTypes.AccGyr: Icons.gps_not_fixed_outlined,
  //ObjectTypes.Servo: Icons.precision_manufacturing_outlined,
  ObjectTypes.Input: Icons.input_outlined,
  //ObjectTypes.Operation: Icons.settings_outlined,
  ObjectTypes.Program: Icons.terminal_outlined,
  ObjectTypes.I2C: Icons.account_tree_outlined,
  ObjectTypes.UART: Icons.account_tree_outlined,
  ObjectTypes.SPI: Icons.account_tree_outlined,
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
  Types.AccGyr: Icons.screen_rotation,
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
