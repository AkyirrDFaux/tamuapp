import 'types.dart';

Map<Types, List<String>> typeToValueNames = {
  Types.Status: [
    "OK",
    "InvalidID",
    "InvalidType",
    "InvalidFunction",
    "InvalidValue",
    "MissingModule",
    "FileError",
    "PortError",
    "NoValue",
    "AutoObject",
    "OutOfFlash",
    "NotInFlash",
    "FlashWritten"
  ],
  Types.Board: [
    "Undefined",
    "Tamu v1.0",
    "Tamu v2.0",
  ],
  Types.PortDriver: [
    "None",     // 0
    "Input",    // 1
    "Output",   // 2
    "PWM",      // 3
    "Servo",    // 4
    "LED",      // 5
    "I2C_SDA",  // 6
    "I2C_SCL",  // 7
    "UART_TX",  // 8
    "UART_RX"   // 9
  ],
  Types.Geometry2D: [
    "None",
    "Box",
    "Ellipse",
    "Triangle",
    "Polygon",
    "Star",
    "DoubleParabola",
    "Fill",
    "HalfFill",
  ],
  Types.Texture1D: [
    "None",
    "Full",
    "Blend",
    "Noise",
  ],
  Types.Texture2D: [
    "None",
    "Full",
    "BlendLinear",
    "BlendCircular",
    "Noise",
  ],
  Types.GeometryOperation: [
    "Add",
    "Cut",
    "Intersect",
    "XOR",
  ],
  Types.Display: [
    "Undefined",
    "Vysi v1.0",
  ],
  Types.LEDStrip: [
    "Undefined",
    "Generic RGB",
    "Generic RGBW"
  ],
  Types.AccGyr: [
    "Undefined",
    "LSM6DS3TRC"
  ],
  Types.Input :  [
  "Undefined",
  "Button",
  "ButtonWithLED",
  "Analog"
  ],
  Types.Program: [
    "None",
    "Sequence",
    "All",
  ],
  Types.Operation: [
    "None",
    "Equal",
    "Extract",
    "Combine",
    "IsEqual",
    "IsGreater",
    "IsSmaller",
    "Add",
    "Subtract",
    "Multiply",
    "Divide",
    "Power",
    "Absolute",
    "Rotate",
    "RandomBetween",
    "MoveTo",
    "Delay",
    "AddDelay",
    "IfSwitch",
    "While",
    "SetActivity",
  ],
};

String? getValueEnum(Types type, int index) {
  List<String>? stringsForType = typeToValueNames[type];
  if (stringsForType != null && index >= 0 && index < stringsForType.length) {
    return stringsForType[index];
  }
  return null; // Type not found or index out of bounds
}

bool isInValueEnum(Types type){
  List<String>? stringsForType = typeToValueNames[type];
  if (stringsForType == null) {
    return false;
  }
  return true;
}

Map<int, String>? getValueEnumMap(Types type) {
  final List<String>? names = typeToValueNames[type];
  if (names == null) return null;

  // Converts ["OK", "InvalidID"] into {0: "OK", 1: "InvalidID"}
  return names.asMap();
}