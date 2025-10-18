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
    return MaterialApp(home: MainPage());
  }
}

/*TODO:
Improve formatting of values

Object graph navigation (history)

Quick actions

Autoconnect?
IDList to normal list?
 */