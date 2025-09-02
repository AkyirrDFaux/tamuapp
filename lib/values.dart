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
  ],
  Types.Board: [
    "Undefined",
    "Tamu_v1_0",
    "Tamu_v2_0",
  ],
  Types.Port: [
    "None",
    "GPIO",
    "TOut",
  ],
  Types.PortDriver: [
    "None",
    "LED",
    "FanPWM",
  ],
  Types.Geometry2D: [
    "None",
    "Box",
    "Elipse",
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
    "Vysi_v1_0",
  ],
  Types.LEDStrip: [
    "Undefined",
    "Generic",
  ],
  Types.AnimationFloat: [
    "None",
    "MoveTo",
    "MoveBetween",
  ],
  Types.AnimationVector: [
    "None",
    "MoveTo",
    "MoveBetween",
  ],
  Types.AnimationCoord: [
    "None",
    "MoveTo",
  ],
  Types.AnimationColour: [
    "None",
    "TimeBlend",
    "BlendLoop",
    "BlendRGB",
  ],
  Types.Program: [
    "None",
    "Sequence",
    "All",
  ],
  Types.Operation: [
    "None",
    "Equal",
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