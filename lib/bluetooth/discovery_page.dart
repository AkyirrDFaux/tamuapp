import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_manager.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final BluetoothManager _bluetoothManager = BluetoothManager();
  List<ScanResult> _devices = [];
  bool _isDiscovering = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopDiscovery();
    _scanSubscription?.cancel();
    super.dispose();
  }

  void _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _devices.clear();
    });
    await _bluetoothManager.requestEnableBluetooth();
    _bluetoothManager.startScan();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (_isDisposed) return;
      for (ScanResult r in results) {
        if (!mounted) return;
        setState(() {
          final existingIndex = _devices.indexWhere((element) => element.device.remoteId == r.device.remoteId);
          if (existingIndex >= 0) {
            _devices[existingIndex] = r;
          } else {
            _devices.add(r);
          }
          _devices.sort((a, b) => b.rssi.compareTo(a.rssi)); // Sort by RSSI
        });
      }
    });
  }

  void _stopDiscovery() {
    _bluetoothManager.stopScan();
    if (!_isDisposed) {
      setState(() {
        _isDiscovering = false;
      });
    }
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -50) {
      return Colors.green; // Strong signal
    } else if (rssi >= -70) {
      return Colors.yellow; // Medium signal
    } else if (rssi >= -90) {
      return Colors.orange; // Weak signal
    } else {
      return Colors.red; // Very weak or no signal
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Devices'),
        actions: [
          if (_isDiscovering)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: _stopDiscovery,
                  ),
                ],
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startDiscovery,
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          final rssiColor = _getRssiColor(device.rssi);
          return ListTile(
            title: Text(device.device.platformName),
            subtitle: Row(
              children: [
                Text('ID: ${device.device.remoteId.str} | '),
                Icon(Icons.signal_cellular_alt, color: rssiColor),
                Text('RSSI: ${device.rssi} dBm', style: TextStyle(color: rssiColor)),
              ],
            ),
            onTap: () {
              _bluetoothManager.setSelectedDevice(device.device);
              Navigator.of(context).pop(device.device);
            },
          );
        },
      ),
    );
  }
}