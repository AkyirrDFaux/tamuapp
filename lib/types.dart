import 'package:flutter/material.dart';

enum Types {
  Undefined(0),
  Bool(1),
  Byte(2),
  Integer(3),
  Number(4),
  Time(5),
  ID(6),
  Colour(7),
  Vector2D(8),
  Vector3D(9),
  Coord2D(10),
  Coord3D(11),
  Text(12),
  IDList(13),
  ObjectType(32),
  Function(33),
  Flags(34),
  Status(35),
  Board(36),
  Port(37),
  PortDriver(38),
  AccGyr(39),
  Input(40),
  LEDStrip(41),
  Texture1D(42),
  Display(43),
  Geometry2D(44),
  GeometryOperation(45),
  Texture2D(46),
  Operation(47),
  Program(48);

  final int value;
  const Types(this.value);

  static int getSize(Types type) {
    if (type == Types.Undefined) {
      return 0;
    } else if (type.value <= Types.Byte.value || type.value >= Types.ObjectType.value) {
      return 1;
    } else if (type.value <= Types.Colour.value) {
      return 4;
    } else if (type == Types.Vector2D) {
      return 8;
    } else if (type == Types.Vector3D) {
      return 12;
    } else if (type == Types.Coord2D) {
      return 16;
    } else if (type == Types.Coord3D) {
      return 24;
    } else {
      return -1; // dynamic, check first byte
    }
  }

  static Types fromValue(int value) {
    for (var type in Types.values) {
      if (type.value == value) {
        return type;
      }
    }
    return Types.Undefined;
  }
}

enum ObjectTypes {
  Undefined(0),
  Shape2D(1),
  Board(2),
  Port(3),
  Fan(4),
  LEDStrip(5),
  LEDSegment(6),
  Texture1D(7),
  Display(8),
  Geometry2D(9),
  Texture2D(10),
  AccGyr(11),
  Servo(12),
  Input(13),
  Operation(14),
  Program(15);

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
  ObjectTypes.Shape2D: Icons.category_outlined,
  ObjectTypes.Board: Icons.memory_outlined,
  ObjectTypes.Port: Icons.lan_outlined,
  ObjectTypes.Fan: Icons.wind_power_outlined,
  ObjectTypes.LEDStrip: Icons.wb_incandescent_outlined,
  ObjectTypes.LEDSegment: Icons.view_agenda_outlined,
  ObjectTypes.Texture1D: Icons.linear_scale_outlined,
  ObjectTypes.Display: Icons.desktop_windows_outlined,
  ObjectTypes.Geometry2D: Icons.square_foot_outlined,
  ObjectTypes.Texture2D: Icons.texture_outlined,
  ObjectTypes.AccGyr: Icons.gps_not_fixed_outlined,
  ObjectTypes.Servo: Icons.precision_manufacturing_outlined,
  ObjectTypes.Input: Icons.input_outlined,
  ObjectTypes.Operation: Icons.settings_outlined,
  ObjectTypes.Program: Icons.terminal_outlined,
};

final Map<Types, IconData> typeIcons = {
  Types.Undefined: Icons.help_outline,
  Types.Bool: Icons.toggle_on_outlined,
  Types.Byte: Icons.data_object_outlined,
  Types.Integer: Icons.pin_outlined,
  Types.Number: Icons.looks_one_outlined,
  Types.Time: Icons.schedule_outlined,
  Types.ID: Icons.tag_outlined,
  Types.Colour: Icons.color_lens_outlined,
  Types.Vector2D: Icons.open_in_full_outlined,
  Types.Vector3D: Icons.navigation_outlined,
  Types.Coord2D: Icons.place_outlined,
  Types.Coord3D: Icons.threed_rotation,
  Types.Text: Icons.title_outlined,
  Types.IDList: Icons.list_alt_outlined,
  Types.ObjectType: Icons.sell_outlined,
  Types.Function: Icons.functions_outlined,
  Types.Flags: Icons.flag_outlined,
  Types.Status: Icons.info_outline,
  Types.Board: Icons.memory_outlined,
  Types.Port: Icons.lan_outlined,
  Types.PortDriver: Icons.tune_outlined,
  Types.AccGyr: Icons.gps_not_fixed_outlined,
  Types.Input: Icons.input_outlined,
  Types.LEDStrip: Icons.wb_incandescent_outlined,
  Types.Texture1D: Icons.linear_scale_outlined,
  Types.Display: Icons.desktop_windows_outlined,
  Types.Geometry2D: Icons.square_foot_outlined,
  Types.GeometryOperation: Icons.gesture_outlined,
  Types.Texture2D: Icons.texture_outlined,
  Types.Operation: Icons.settings_outlined,
  Types.Program: Icons.terminal_outlined,
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
