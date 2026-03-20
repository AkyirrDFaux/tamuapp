import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart' as universal_ble;

import 'bluetooth/discovery_page.dart';
import 'bluetooth/bluetooth_manager.dart';
import 'message/queue_page.dart';
import 'object/object_list_page.dart';
//import 'object/object_graph_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<StatefulWidget> createState() => _MainPage();
}

class _MainPage extends State<MainPage> {
  @override
  void initState() {
    super.initState();
    // ... (permission logic remains the same)
  }

  Widget _buildMenuButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? contentColor, // Combined icon/text color for simplicity
  }) {
    final theme = Theme.of(context);

    // Default to the secondary slate grey from your theme
    final effectiveBg = backgroundColor ?? theme.colorScheme.secondary;
    final effectiveContent = contentColor ?? Colors.white;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: effectiveBg,
          foregroundColor: effectiveContent,
          minimumSize: const Size(double.infinity, 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 0, // Flat as requested
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 36.0, color: effectiveContent),
            const SizedBox(height: 8.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Menu'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Consumer<BluetoothManager>(
                    builder: (context, manager, child) {
                      String buttonText;
                      Color currentButtonColor = theme.colorScheme.secondary;
                      Color currentContentColor = Colors.white;

                      final deviceName = manager.selectedDevice?.name ?? "Device";

                      if (manager.selectedDevice == null) {
                        buttonText = 'Explore\nDevices';
                      } else if (manager.isConnecting) {
                        buttonText = 'Connecting to\n$deviceName';
                      } else if (manager.isConnected) {
                        buttonText = 'Connected to\n$deviceName';
                        if (manager.connectionType == ConnectionType.uart) {
                          currentButtonColor = theme.colorScheme.primary;
                          currentContentColor = Colors.black;
                        } else {
                          currentButtonColor = Colors.blue.shade700;
                          currentContentColor = Colors.white;
                        }
                      } else {
                        buttonText = 'Connection Failed';
                      }

                      return _buildMenuButton(
                        title: buttonText,
                        icon: Icons.bluetooth,
                        backgroundColor: currentButtonColor,
                        contentColor: currentContentColor,
                        onPressed: () async {
                          // 1. Request Permissions
                          if (await Permission.bluetoothScan.isDenied ||
                              await Permission.bluetoothConnect.isDenied) {
                            await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
                          }

                          // 2. Check if Bluetooth is actually ON
                          if (manager.bluetoothState != universal_ble.AvailabilityState.poweredOn) {
                            try {
                              await universal_ble.UniversalBle.enableBluetooth();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Bluetooth could not be enabled.')),
                                );
                              }
                              return;
                            }
                          }

                          // 3. Handle Navigation or Disconnection
                          if (manager.isConnected) {
                            manager.disconnect();
                          } else {
                            // Open Discovery Page and wait for result
                            final selectedDevice = await Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const DiscoveryPage()),
                            );

                            if (selectedDevice != null) {
                              manager.setSelectedDevice(selectedDevice);
                            }
                          }
                        },
                      );
                    },
                  ),
                  _buildMenuButton(
                    title: 'Message\nInspector',
                    icon: Icons.forum_outlined,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const QueuePage()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildMenuButton(
                    title: 'Object\nList',
                    icon: Icons.view_list_outlined,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ObjectListPage()),
                      );
                    },
                  ),
                  /*_buildMenuButton(
                    title: 'Object\nGraph',
                    icon: Icons.hub_outlined,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ObjectGraphPage()),
                      );
                    },
                  ),*/
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}