import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'bluetooth/discovery_page.dart';
import 'bluetooth/bluetooth_manager.dart';
import 'message/queue_page.dart';
import 'object/object_list_page.dart';
import 'object/object_graph_page.dart';

class MainPage extends StatefulWidget{
  const MainPage({super.key});

  @override
  State<StatefulWidget> createState() => _MainPage();
}

class _MainPage extends State<MainPage>{

  @override
  void initState() {
    super.initState();

    Future.doWhile(() async {
      if ((await Permission.bluetoothConnect.request()).isGranted &&
          (await Permission.bluetoothScan.request()).isGranted) {
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 200)); // Add a small delay
      return true;
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Menu'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Consumer<BluetoothManager>(
              builder: (context, manager, child) {
                return ElevatedButton(
                  child: Text(
                    manager.selectedDevice == null
                        ? 'Explore discovered devices'
                        : manager.isConnecting
                        ? 'Connecting to ${manager.selectedDevice!.name}...'
                        : manager.isConnected
                        ? 'Connected to ${manager.selectedDevice!.name}'
                        : 'Failed to connect to ${manager.selectedDevice!.name}',
                  ),
                  onPressed: () async {
                    // Corrected check:
                    if (manager.bluetoothState != BluetoothAdapterState.on) {
                      // Request to enable Bluetooth, if it isn't
                      await manager.requestEnableBluetooth();
                      if (manager.bluetoothState != BluetoothAdapterState.on) {
                        return;
                      }
                    }
                    if (manager.isConnected) {
                      manager.disconnect();
                    } else {
                      final BluetoothDevice? selectedDevice =
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) {
                            return const DiscoveryPage();
                          },
                        ),
                      );
                      if (selectedDevice != null) {
                        manager.setSelectedDevice(selectedDevice);
                      }
                    }
                  },
                );
              },
            ),
          ),
          ListTile(
            title: ElevatedButton(
              child: const Text('Object List'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ObjectListPage(),
                  ),
                );
              },
            ),
          ),
          ListTile(
            title: ElevatedButton(
              child: const Text('Object Graph'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ObjectGraphPage(),
                  ),
                );
              },
            ),
          ),
          ListTile(
            title: ElevatedButton(
              child: const Text('Message Queue'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const QueuePage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}