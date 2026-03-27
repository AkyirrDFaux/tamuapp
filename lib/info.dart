enum Flags {
  none(0),
  auto(1),          // 0b00000001
  undefined1(2),    // 0b00000010
  undefined2(4),    // 0b00000100
  undefined3(8),    // 0b00001000
  undefined4(16),   // 0b00010000
  runOnce(32),      // 0b00100000
  runOnStartup(64), // 0b01000000
  inactive(128);    // 0b10000000

  final int value;
  const Flags(this.value);
}

class FlagClass {
  int value = 0;
  FlagClass([this.value = 0]);

  bool has(Flags flag) => (value & flag.value) != 0;
  void add(Flags flag) => value |= flag.value;
  void remove(Flags flag) => value &= ~flag.value;

  void setBit(int index) {
    if (index >= 0 && index < 8) value |= (1 << index);
  }

  void clearBit(int index) {
    if (index >= 0 && index < 8) value &= ~(1 << index);
  }

  bool isBitSet(int index) {
    return (index >= 0 && index < 8) ? (value & (1 << index)) != 0 : false;
  }

  /// Returns a list of active Flag names
  List<String> get activeNames {
    if (value == 0) return ["none"];
    return Flags.values
        .where((f) => f != Flags.none && has(f))
        .map((f) => f.name)
        .toList();
  }

  @override
  String toString() => "0b${value.toRadixString(2).padLeft(8, '0')} (${activeNames.join(', ')})";
}

class ObjectInfo {
  FlagClass flags;
  int runTiming;

  ObjectInfo({
    FlagClass? flags,
    this.runTiming = 0,
  }) : flags = flags ?? FlagClass();

  @override
  String toString() {
    return "Timing: ${runTiming}ms, Flags: $flags";
  }
}