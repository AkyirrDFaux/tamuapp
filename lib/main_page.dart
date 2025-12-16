import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart' as universal_ble;

import 'bluetooth/discovery_page.dart';
import 'bluetooth/bluetooth_manager.dart';
import 'message/queue_page.dart';
import 'object/object_list_page.dart';
import 'object/object_graph_page.dart';
import 'favorites_page.dart'; // Import the new favorites page

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
    Color? backgroundColor, // Will be overridden by default grey if null
    Color? iconColor,
    Color? textColor, // Optional: for specific text color
  }) {
    final defaultBackgroundColor = Colors.grey[300]!;
    final effectiveBackgroundColor = backgroundColor ?? defaultBackgroundColor;

    final bool isDarkBackground = ThemeData.estimateBrightnessForColor(effectiveBackgroundColor) == Brightness.dark;

    final defaultContentColor = isDarkBackground ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: textColor ?? defaultContentColor,
          minimumSize: const Size(double.infinity, 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          textStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textColor ?? defaultContentColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 36.0, color: iconColor ?? defaultContentColor),
            const SizedBox(height: 8.0),
            Text(
              title,
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bluetoothConnectedColor = Colors.blue;
    const Color defaultButtonTextColor = Colors.black;
    const Color bluetoothConnectedTextColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Menu'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Left Column
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Consumer<BluetoothManager>(
                    builder: (context, manager, child) {
                      String buttonText;
                      Color? currentButtonColor;
                      Color? currentTextColor = defaultButtonTextColor;
                      Color? currentIconColor = defaultButtonTextColor;

                      if (manager.selectedDevice == null) {
                        buttonText = 'Explore\nDevices';
                      } else if (manager.isConnecting) {
                        buttonText = 'Connecting to\n${manager.selectedDevice!.name}';
                      } else if (manager.isConnected) {
                        buttonText = 'Connected to\n${manager.selectedDevice!.name}';
                        currentButtonColor = bluetoothConnectedColor;
                        currentTextColor = bluetoothConnectedTextColor;
                        currentIconColor = bluetoothConnectedTextColor;
                      } else {
                        buttonText = 'Connection Failed\n${manager.selectedDevice!.name}';
                      }

                      return _buildMenuButton(
                        title: buttonText,
                        icon: Icons.bluetooth,
                        backgroundColor: currentButtonColor,
                        textColor: currentTextColor,
                        iconColor: currentIconColor,
                        onPressed: () async {
                          if (await Permission.bluetoothScan.isDenied || await Permission.bluetoothConnect.isDenied) {
                            await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
                          }

                          if (manager.bluetoothState != universal_ble.AvailabilityState.poweredOn) {
                            try {
                              await universal_ble.UniversalBle.enableBluetooth();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Bluetooth could not be enabled.')),
                              );
                              return;
                            }
                            await Future.delayed(const Duration(milliseconds: 500));
                            if (manager.bluetoothState != universal_ble.AvailabilityState.poweredOn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enable Bluetooth.')),
                              );
                              return;
                            }
                          }

                          if (manager.isConnected) {
                            manager.disconnect();
                          } else {
                            final universal_ble.BleDevice? selectedDevice =
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
                  _buildMenuButton(
                    title: 'Message\nQueue',
                    icon: Icons.forum_outlined,
                    textColor: defaultButtonTextColor,
                    iconColor: defaultButtonTextColor,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const QueuePage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right Column
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildMenuButton(
                    title: 'Favourites',
                    icon: Icons.star_outline,
                    textColor: defaultButtonTextColor,
                    iconColor: defaultButtonTextColor,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const FavoritesPage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuButton(
                    title: 'Object\nList',
                    icon: Icons.view_list_outlined,
                    textColor: defaultButtonTextColor,
                    iconColor: defaultButtonTextColor,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ObjectListPage(),
                        ),
                      );
                    },
                  ),
                  _buildMenuButton(
                    title: 'Object\nGraph',
                    icon: Icons.hub_outlined,
                    textColor: defaultButtonTextColor,
                    iconColor: defaultButtonTextColor,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ObjectGraphPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
