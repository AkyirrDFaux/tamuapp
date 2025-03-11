enum Functions {
  None(0),
  CreateObject(1), // Create new
  DeleteObject(2), // Delete object
  SaveObject(3), // Save to file
  SaveAll(4),
  LoadObject(5), // Create from file
  ReadObject(6), // Send to app
  ReadType(7),
  ReadName(8),
  WriteName(9),
  SetFlags(10),
  ReadModules(11),
  SetModules(12),
  WriteValue(13),
  ReadValue(14),
  ReadDatabase(15), // Debug
  ReadFile(16),
  RunFile(17),
  Refresh(18);

  final int value;
  const Functions(this.value);

  static Functions fromValue(int value) {
    switch (value) {
      case 0:
        return Functions.None;
      case 1:
        return Functions.CreateObject;
      case 2:
        return Functions.DeleteObject;
      case 3:
        return Functions.SaveObject;
      case 4:
        return Functions.SaveAll;
      case 5:
        return Functions.LoadObject;
      case 6:
        return Functions.ReadObject;
      case 7:
        return Functions.ReadType;
      case 8:
        return Functions.ReadName;
      case 9:
        return Functions.WriteName;
      case 10:
        return Functions.SetFlags;
      case 11:
        return Functions.ReadModules;
      case 12:
        return Functions.SetModules;
      case 13:
        return Functions.WriteValue;
      case 14:
        return Functions.ReadValue;
      case 15:
        return Functions.ReadDatabase;
      case 16:
        return Functions.ReadFile;
      case 17:
        return Functions.RunFile;
      case 18:
        return Functions.Refresh;
      default:
        throw ArgumentError("Invalid Functions value: $value");
    }
  }
}