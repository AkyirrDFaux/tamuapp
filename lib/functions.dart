enum Functions {
  None(0),
  CreateObject(1), // Create new
  DeleteObject(2), // Delete object
  LoadObject(3),   // Create from ByteArray
  SaveObject(4),   // Save to file
  SaveAll(5),
  ReadObject(6),   // Send to app
  Refresh(7),
  ReadValue(8),
  WriteValue(9),
  ReadName(10),
  WriteName(11),
  ReadInfo(12),
  SetInfo(13),
  ReadFile(14);

  final int value;
  const Functions(this.value);

  static Functions fromValue(int value) {
    return Functions.values.firstWhere(
          (e) => e.value == value,
      orElse: () => Functions.None,
    );
  }
}