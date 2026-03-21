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

  // Manual bit manipulation by index (0-7)
  void setBit(int index) {
    if (index >= 0 && index < 8) value |= (1 << index);
  }

  void clearBit(int index) {
    if (index >= 0 && index < 8) value &= ~(1 << index);
  }

  bool isBitSet(int index) {
    return (index >= 0 && index < 8) ? (value & (1 << index)) != 0 : false;
  }

  @override
  String toString() => value.toRadixString(2).padLeft(8, '0');
}

class ObjectInfo {
  FlagClass flags;
  int runTiming; // uint8_t equivalent

  ObjectInfo({
    FlagClass? flags,
    this.runTiming = 0,
  }) : flags = flags ?? FlagClass();
}