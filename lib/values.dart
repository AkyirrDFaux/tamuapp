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
    "GenericLEDMatrixWeave",
    "Reserved", "Reserved", "Reserved",
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
    "LSM6DS3TRC",
    "BMI160"
  ],
  Types.Input: [
    "Undefined",
    "Button",
    "ButtonInverted",
    "ButtonWithLED",
    "ButtonWithLEDInverted"
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
  Types.Outputs: [
    "Undefined",
    "PWM",
    "Servo",
  ],
    Types.Operation: [
      "None",             // 0
      "Set",              // 1
      "Delete",           // 2
      "ToBool",           // 3
      "ToByte",           // 4
      "ToInt",            // 5
      "ToNumber",         // 6
      "ToVector2D",       // 7
      "ToVector3D",       // 8
      "ToCoord2D",        // 9
      "ToColour",         // 10
      "ToColourHSV",      // 11
      "Extract",          // 12
      "IsEqual",          // 13
      "IsGreater",        // 14
      "IsSmaller",        // 15
      "Add",              // 16
      "Subtract",         // 17
      "Multiply",         // 18
      "Divide",           // 19
      "Power",            // 20
      "Absolute",         // 21
      "Min",              // 22
      "Max",              // 23
      "Modulo",           // 24
      "Random",           // 25
      "Sine",             // 26
      "Square",           // 27
      "Sawtooth",         // 28
      "Magnitude",        // 29
      "Angle",            // 30
      "Normalize",        // 31
      "DotProduct",       // 32
      "CrossProduct",     // 33
      "Clamp",            // 34
      "Deadzone",         // 35
      "LinInterpolation", // 36
      "And",              // 37
      "Or",               // 38
      "Not",              // 39
      "Edge",             // 40
      "SetReset",         // 41
      "Delay",            // 42
      "IfSwitch",         // 43
      "SetRunOnce",       // 44
      "SetRunLoop",       // 45
      "SetReference",
      "Save"
    ]
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