import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:universal_ble/universal_ble.dart';
import 'bluetooth_manager.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final BluetoothManager _bluetoothManager = BluetoothManager();
  final List<BleDevice> _devices = [];
  List<String> _serialPorts = [];

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) {
      _discoverPorts();
    }
    _startDiscovery();
  }

  @override
  void dispose() {
    _stopDiscovery(notify: false);
    super.dispose();
  }

  void _discoverPorts() {
    if (Platform.isAndroid) return;
    setState(() {
      _serialPorts = SerialPort.availablePorts;
    });
  }

  void _startDiscovery() async {
    if (!mounted) return;
    setState(() {
      _devices.clear();
    });
    UniversalBle.onScanResult = (device) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() {
          final existingIndex = _devices.indexWhere((element) => element.deviceId == device.deviceId);
          if (existingIndex >= 0) {
            _devices[existingIndex] = device;
          } else {
            _devices.add(device);
          }
          _devices.sort((a, b) => (b.rssi ?? -100).compareTo((a.rssi ?? -100))); // Sort by RSSI
        });
      });
    };
    await _bluetoothManager.requestEnableBluetooth();
    await _bluetoothManager.startScan();
  }

  void _stopDiscovery({bool notify = true}) {
    _bluetoothManager.stopScan(notify: notify);
  }

  Color _getRssiColor(int? rssi) {
    if (rssi == null) return Colors.grey;
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
          if (_bluetoothManager.isScanning)
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
              onPressed: (){
                if (!Platform.isAndroid) {
                  _discoverPorts();
                }
                _startDiscovery();
              },
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: _devices.length + (Platform.isAndroid ? 0 : _serialPorts.length),
        itemBuilder: (context, index) {
          if (!Platform.isAndroid && index < _serialPorts.length) {
            final portName = _serialPorts[index];
            return ListTile(
              title: Text(portName),
              subtitle: const Text('UART Device'),
              onTap: () {
                _bluetoothManager.setSelectedDevice(portName);
                Navigator.of(context).pop(portName);
              },
            );
          } else {
            final deviceIndex = Platform.isAndroid ? index : index - _serialPorts.length;
            if (deviceIndex >= _devices.length) return null; // Should not happen
            final device = _devices[deviceIndex];
            final rssiColor = _getRssiColor(device.rssi);
            return ListTile(
              title: Text(device.name ?? 'Unknown Device'),
              subtitle: Row(
                children: [
                  Text('ID: ${device.deviceId} | '),
                  Icon(Icons.signal_cellular_alt, color: rssiColor),
                  Text('RSSI: ${device.rssi ?? 'N/A'} dBm', style: TextStyle(color: rssiColor)),
                ],
              ),
              onTap: () {
                _bluetoothManager.setSelectedDevice(device);
                Navigator.of(context).pop(device);
              },
            );
          }
        },
      ),
    );
  }
}
