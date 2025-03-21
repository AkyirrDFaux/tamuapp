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
  AnimationFloat(20),
  AnimationVector(21),
  AnimationCoord(22),
  AnimationColour(23),
  Operation(24),
  Program(25),
  Integer(26),
  Time(27),
  Number(28),
  ID(29),
  Colour(30),
  PortAttach(31),
  Vector2D(32),
  Coord2D(33),
  Text(34),
  IDList(35);

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
        return Types.AnimationFloat;
      case 21:
        return Types.AnimationVector;
      case 22:
        return Types.AnimationCoord;
      case 23:
        return Types.AnimationColour;
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
        return Types.Coord2D;
      case 34:
        return Types.Text;
      case 35:
        return Types.IDList;
      default:
        return Types.Undefined;
    }
  }
}