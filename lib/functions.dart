enum Functions {
  None(0),
  Report(1),
  CreateObject(2),
  DeleteObject(3),
  LoadObject(4),
  SaveObject(5),
  SaveAll(6),
  ReadObject(7),
  Refresh(8),
  ReadValue(9),
  WriteValue(10),
  ReadName(11),
  WriteName(12),
  ReadInfo(13),
  SetInfo(14),
  ReadFile(15);

  final int value;
  const Functions(this.value);

  static Functions fromValue(int value) {
    return Functions.values.firstWhere(
          (e) => e.value == value,
      orElse: () => Functions.None,
    );
  }
}