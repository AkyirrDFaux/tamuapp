import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'message/message_queue.dart';
import 'bluetooth/bluetooth_manager.dart';
import 'main_page.dart';
import 'object/object_manager.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => BluetoothManager()),
        ChangeNotifierProvider(create: (context) => MessageQueue()),
        ChangeNotifierProvider(create: (context) => ObjectManager()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Apply the theme here
      theme: mcuTheme,
      // Force dark mode to prevent system overrides from showing white backgrounds
      themeMode: ThemeMode.dark,
      home: const MainPage(),
    );
  }
}

final ThemeData mcuTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,

  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFF57600),   // Accent Orange
    onPrimary: Colors.black,      // Black text on Orange buttons/bars
    secondary: Color(0xFF4F575C), // Bubble Grey
    onSecondary: Colors.white,
    surface: Color(0xFF353C3F),   // Main BG
    onSurface: Colors.white,
    error: Colors.red,
    onError: Colors.white,
  ),

  scaffoldBackgroundColor: const Color(0xFF353C3F),

  // --- GLOBAL APPBAR OVERRIDE ---
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFE16D00), // Global Accent Orange
    foregroundColor: Colors.black,      // Global Black Text/Icons
    elevation: 0,
    scrolledUnderElevation: 0,         // Stops color change on scroll
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    iconTheme: IconThemeData(color: Colors.black),
    titleTextStyle: TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.w600,
      fontSize: 20,
    ),
  ),

  // --- GLOBAL BUTTON STYLE ---
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF4F575C),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    ),
  ),

  dividerTheme: const DividerThemeData(
    color: Color(0xFFF57600),
    thickness: 1,
    space: 1,
  ),

  // --- TEXT CONTRAST ---
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
    bodyMedium: TextStyle(color: Colors.white, fontSize: 15),
    bodySmall: TextStyle(color: Colors.white70, fontSize: 12),
  ),

  snackBarTheme: const SnackBarThemeData(
    backgroundColor: Color(0xFF4F575C), // Bubble Grey (Secondary)
    contentTextStyle: TextStyle(color: Colors.white, fontSize: 14), // onSecondary
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
);

/*TODO:
Improve formatting of values

Object graph navigation (history)

Quick actions

Autoconnect?
IDList to normal list?
 */