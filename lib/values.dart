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
    "Undefined",    // 0
    "Tamu v1.0",    // 1
    "Tamu v2.0",    // 2
    "Reserved", "Reserved", "Reserved", "Reserved",
    "Reserved", "Reserved", "Reserved", "Reserved", "Reserved",
    "Valu v2.0",    // 12
  ],
  Types.PortDriver: [
    "None",     // 0
    "Input",    // 1
    "Analog",   // 2
    "Output",   // 3
    "LED",      // 4
    "I2C_SDA",  // 5
    "I2C_SCL",  // 6
    "UART_TX",  // 7
    "UART_RX",  // 8
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
    "Point",    // Added missing index
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
    "Undefined",        // 0
    "GenericLEDMatrix", // 1
    "Reserved", "Reserved", "Reserved", "Reserved",
    "Reserved", "Reserved", "Reserved", "Reserved",
    "Vysi v1.0",        // 10
  ],
  Types.LEDStrip: [
    "Undefined",
    "Generic RGB",
    "Generic RGBW"
  ],
  Types.I2CDevice: [
    "Undefined",
    "LSM6DS3TRC"
  ],
  Types.Input: [
    "Undefined",
    "Button",
    "ButtonWithLED",
  ],
  Types.Sensor: [       // Added missing SensorTypes
    "Undefined",
    "AnalogVoltage",
    "TempNTC10K",
    "Light10K"
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
    "SetFlags",    // Updated from SetActivity
    "ResetFlags",  // Added
    "Sine"         // Added
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

class PortFlags {
  static const Map<int, String> names = {
    0: "None",
    1 << 0: "GPIO",
    1 << 1: "ADC",
    1 << 2: "PWM",
    1 << 3: "TOut",
    1 << 4: "Internal",
    1 << 8: "I2C_SDA",
    1 << 9: "I2C_SCL",
    1 << 12: "UART_TX",
    1 << 13: "UART_RX",
    1 << 16: "SPI_MOSI",
    1 << 17: "SPI_MISO",
    1 << 18: "SPI_CLK",
    1 << 19: "SPI_CS",
    1 << 20: "SPI_DRST",
    1 << 21: "SPI_DDC",
  };

  /// Helper to get a list of all active flag names from a bitmask value
  static List<String> getActiveFlags(int mask) {
    if (mask == 0) return ["None"];

    return names.entries
        .where((e) => e.key != 0 && (mask & e.key) != 0)
        .map((e) => e.value)
        .toList();
  }
}