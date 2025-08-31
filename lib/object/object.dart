import '../flags.dart';
import '../types.dart';

class Object {
  final Types type;
  int id;
  String name = "Unnamed";
  FlagClass flags = FlagClass();
  List<MapEntry<int, int>> modules = <MapEntry<int, int>>[];
  dynamic value;

  Object({
    required this.type,
    required this.id,
  });

  List<Object> references(List<Object> allObjects) {
    List<Object> result = [];
    for (Object obj in allObjects) {
      if (obj.modules.any((module) => module.key == id)) {
        result.add(obj);
      }
    }
    return result;
  }
}

class Vector2D {
  double X = 0;
  double Y = 0;

  Vector2D(this.X, this.Y);
  @override
  String toString() {
    return 'Vector2D(X: $X, Y: $Y)';
  }
}

class Coord2D {
  Vector2D Position = Vector2D(0, 0);
  Vector2D Rotation = Vector2D(1, 0);

  Coord2D(this.Position, this.Rotation);

  @override
  String toString() {
    return 'Coord2D(Position: $Position, Rotation: $Rotation)';
  }
}

class Colour {
  int R = 0;
  int G = 0;
  int B = 0;
  int A = 0;
  Colour(this.R, this.G, this.B, this.A);

  @override
  String toString() {
    return 'Colour(R: $R, G: $G, B: $B, A: $A)';
  }
}