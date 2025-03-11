enum Flags {
  none(0),
  auto(1), // 0b00000001
  none1(2),
  none2(4),
  runLoop(8), // 0b00001000
  runOnce(16), // 0b00010000
  runOnStartup(32), // 0b00100000
  favourite(64), // 0b01000000
  inactive(128); // 0b10000000

  final int value;
  const Flags(this.value);
}

class FlagClass{
  int value = 0;
  FlagClass([this.value = 0]);

  bool hasFlag(Flags flag) {
    return (value & flag.value) != 0;
  }

  int addFlag(Flags flag) {
    return value | flag.value;
  }

  int removeFlag(Flags flag) {
    return value & ~flag.value;
  }

  void set(int index) {
    if (index >= 0 && index < 8) {
      value |= (1 << index);
    }
  }

  void clear(int index) {
    if (index >= 0 && index < 8) {
      value &= ~(1 << index);
    }
  }

  bool isSet(int index) {
    if (index >= 0 && index < 8) {
      return (value & (1 << index)) != 0;
    }
    return false;
  }

  @override
  String toString() {
    return value.toRadixString(2).padLeft(8, '0');
  }
}