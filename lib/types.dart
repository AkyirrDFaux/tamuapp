import 'package:flutter/material.dart';

enum Types {
  Undefined(0),
  Folder(1),
  Shape2D(2),
  Byte(3),
  Bool(4),
  Type(5),
  Function(6),
  Flags(7),
  Status(8),
  Board(9),
  Port(10),
  PortDriver(11),
  Fan(12),
  LEDStrip(13),
  LEDSegment(14),
  Texture1D(15),
  Display(16),
  Geometry2D(17),
  GeometryOperation(18),
  Texture2D(19),
  AccGyr(20),
  Removed2(21),
  Removed3(22),
  Removed4(23),
  Operation(24),
  Program(25),
  Integer(26),
  Time(27),
  Number(28),
  ID(29),
  Colour(30),
  PortAttach(31),
  Vector2D(32),
  Vector3D(33),
  Coord2D(34),
  Text(35),
  IDList(36);

  final int value;
  const Types(this.value);

  static int getSize(Types type) {
    if (type.value < Types.Byte.value)
      return 0;
    else if (type.value < Types.Integer.value)
      return 1;
    else if (type.value < Types.Vector2D.value)
      return 4;
    else if (type.value == Types.Vector2D.value)
      return 8;
    else if (type.value == Types.Vector3D.value)
      return 12;
    else if (type.value == Types.Coord2D.value)
      return 16;
    else
      return -1; // dynamic, check first byte
  }

  static Types fromValue(int value) {
    switch (value) {
      case 0:
        return Types.Undefined;
      case 1:
        return Types.Folder;
      case 2:
        return Types.Shape2D;
      case 3:
        return Types.Byte;
      case 4:
        return Types.Bool;
      case 5:
        return Types.Type;
      case 6:
        return Types.Function;
      case 7:
        return Types.Flags;
      case 8:
        return Types.Status;
      case 9:
        return Types.Board;
      case 10:
        return Types.Port;
      case 11:
        return Types.PortDriver;
      case 12:
        return Types.Fan;
      case 13:
        return Types.LEDStrip;
      case 14:
        return Types.LEDSegment;
      case 15:
        return Types.Texture1D;
      case 16:
        return Types.Display;
      case 17:
        return Types.Geometry2D;
      case 18:
        return Types.GeometryOperation;
      case 19:
        return Types.Texture2D;
      case 20:
        return Types.AccGyr;
      case 21:
        return Types.Removed2;
      case 22:
        return Types.Removed3;
      case 23:
        return Types.Removed4;
      case 24:
        return Types.Operation;
      case 25:
        return Types.Program;
      case 26:
        return Types.Integer;
      case 27:
        return Types.Time;
      case 28:
        return Types.Number;
      case 29:
        return Types.ID;
      case 30:
        return Types.Colour;
      case 31:
        return Types.PortAttach;
      case 32:
        return Types.Vector2D;
      case 33:
        return Types.Vector3D;
      case 34:
        return Types.Coord2D;
      case 35:
        return Types.Text;
      case 36:
        return Types.IDList;
      default:
        return Types.Undefined;
    }
  }
}

final Map<Types, IconData> typeIcons = {
  Types.Undefined: Icons.help_outline,
  Types.Folder: Icons.folder_outlined,
  Types.Shape2D: Icons.category_outlined, // Good for abstract shapes
  Types.Byte: Icons.data_object_outlined,
  Types.Bool: Icons.toggle_on_outlined, // Or Icons.check_box_outlined
  Types.Type: Icons.sell_outlined, // Represents a tag or type label
  Types.Function: Icons.functions_outlined,
  Types.Flags: Icons.flag_outlined,
  Types.Status: Icons.info_outline,
  Types.Board: Icons.memory_outlined,
  Types.Port: Icons.lan_outlined,
  Types.PortDriver: Icons.tune_outlined, // Chip icon, often related to drivers
  Types.Fan: Icons.wind_power_outlined,
  Types.LEDStrip: Icons.wb_incandescent_outlined, // Lightbulb
  Types.LEDSegment: Icons.view_agenda_outlined, // Segments in a row
  Types.Texture1D: Icons.linear_scale_outlined,
  Types.Display: Icons.desktop_windows_outlined,
  Types.Geometry2D: Icons.square_foot_outlined, // Ruler and angle
  Types.GeometryOperation: Icons.gesture_outlined, // Hand drawing
  Types.Texture2D: Icons.texture_outlined,
  Types.AccGyr: Icons.gps_not_fixed_outlined,
  Types.Removed2: Icons.delete_outline,
  Types.Removed3: Icons.delete_outline,
  Types.Removed4: Icons.delete_outline,
  Types.Operation: Icons.settings_outlined, // Gears for operations
  Types.Program: Icons.terminal_outlined,
  Types.Integer: Icons.pin_outlined, // Numbered pin
  Types.Time: Icons.schedule_outlined,
  Types.Number: Icons.looks_one_outlined, // Or more generic: Icons.calculate_outlined
  Types.ID: Icons.tag_outlined,
  Types.Colour: Icons.color_lens_outlined,
  Types.PortAttach: Icons.link_outlined,
  Types.Vector2D: Icons.open_in_full_outlined, // Expand/vectorial idea
  Types.Vector3D: Icons.navigation_outlined, // Expand/vectorial idea
  Types.Coord2D: Icons.place_outlined,
  Types.Text: Icons.title_outlined,
  Types.IDList: Icons.list_alt_outlined,
};

// Example of how to use it:
IconData getIconForType(Types type) {
  return typeIcons[type] ?? Icons.device_unknown; // Fallback icon
}