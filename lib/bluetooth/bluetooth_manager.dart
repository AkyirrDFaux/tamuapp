import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../message/message.dart';
import '../message/message_queue.dart';
import '../object/object_manager.dart';

class BluetoothManager extends ChangeNotifier {
  // 1. Private Static Instance
  static final BluetoothManager _instance = BluetoothManager._internal();

  // 2. Factory Constructor
  factory BluetoothManager() {
    return _instance;
  }

  // 3. Private Constructor
  BluetoothManager._internal() {
    // Listen to Bluetooth state changes
    UniversalBle.onAvailabilityChange = (state) {
      Future.microtask(() {
        _updateBluetoothState(state);
      });
    };

    UniversalBle.onConnectionChange = (String deviceId, bool isConnected, String? errorMessage) {
      Future.microtask(() async {
        if (deviceId != _device?.deviceId) return;

        _isConnected = isConnected;
        _isConnecting = false;

        if (_isConnected) {
          try {
            final services = await UniversalBle.discoverServices(_device!.deviceId);
            _services.clear();
            _services.addAll(services);
            await _findCharacteristics();
          } catch (e) {
            _isConnected = false;
          }
        } else {
          // Cleanup on disconnect
          _writeCharacteristic = null;
          _notifyCharacteristic = null;
          _writeCharacteristicServiceUuid = null;
          _notifyCharacteristicServiceUuid = null;
          _services.clear();
          _receivedData = Uint8List(0);
          UniversalBle.onValueChange = null;
        }
        notifyListeners();
      });
    };
  }

  BleDevice? _device;
  BleCharacteristic? _writeCharacteristic;
  String? _writeCharacteristicServiceUuid;
  BleCharacteristic? _notifyCharacteristic;
  String? _notifyCharacteristicServiceUuid;
  final List<BleService> _services = [];

  AvailabilityState _bluetoothState = AvailabilityState.unsupported;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isScanning = false;

  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  AvailabilityState get bluetoothState => _bluetoothState;
  BleDevice? get selectedDevice => _device;

  Uint8List _receivedData = Uint8List(0);

  void _updateBluetoothState(AvailabilityState state) {
    _bluetoothState = state;
    notifyListeners();
  }

  Future<void> requestEnableBluetooth() async {
    await UniversalBle.enableBluetooth();
  }

  Future<void> startScan() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();
    await UniversalBle.startScan();
  }

  Future<void> stopScan({bool notify = true}) async {
    if (!_isScanning) return;
    _isScanning = false;
    if (notify) {
      notifyListeners();
    }
    UniversalBle.onScanResult = null;
    await UniversalBle.stopScan();
  }

  Future<void> connect() async {
    if (_device == null) {
      return;
    }
    if (_isConnected) {
      disconnect();
    }
    _isConnecting = true;
    notifyListeners();
    try {
      await UniversalBle.connect(_device!.deviceId);
    } catch (error) {
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
    }
  }

  Future<void> _findCharacteristics() async {
    try {
      final mtu = await UniversalBle.requestMtu(_device!.deviceId, 512);
      print('Negotiated MTU: $mtu');
    } catch (e) {
      print('Error requesting MTU: $e');
    }
    for (BleService service in _services) {
      for (BleCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.contains(CharacteristicProperty.write) && _writeCharacteristic == null) {
          _writeCharacteristic = characteristic;
          _writeCharacteristicServiceUuid = service.uuid;
        }
        if (characteristic.properties.contains(CharacteristicProperty.notify) && _notifyCharacteristic == null) {
          _notifyCharacteristic = characteristic;
          _notifyCharacteristicServiceUuid = service.uuid;
          _startNotify();
        }
      }
    }
  }

  void _startNotify() async {
    if (_notifyCharacteristic == null) {
      return;
    }
    await UniversalBle.subscribeNotifications(
      _device!.deviceId,
      _notifyCharacteristicServiceUuid!,
      _notifyCharacteristic!.uuid,
    );
    UniversalBle.onValueChange = _onDataReceived;
  }

  void _onDataReceived(String deviceId, String characteristicId, Uint8List value) {
    // Filter notifications to only the characteristic we are interested in.
    if (characteristicId != _notifyCharacteristic?.uuid) {
      return;
    }
    //print('Received data: ${value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ')}');

    Future.microtask(() {
      // Append the new data to the received data buffer
      final newData = Uint8List(_receivedData.length + value.length);
      newData.setRange(0, _receivedData.length, _receivedData);
      newData.setRange(_receivedData.length, newData.length, value);
      _receivedData = newData;

      // Process the message buffer
      _processMessage();
      notifyListeners();
    });
  }

  void _processMessage() {
    while (_receivedData.length >= 4) {
      final byteData = ByteData.sublistView(_receivedData);
      final messageSize = byteData.getUint32(0, Endian.little);

      if (_receivedData.length >= messageSize + 4) {
        // We have a complete message
        final messageData = _receivedData.sublist(0, messageSize + 4);

        QueueEntry entry = QueueEntry(
            message: Message.fromBytes(messageData),
            timestamp: DateTime.now(),
            direction: MessageDirection.input);
        MessageQueue().addEntry(entry);
        ObjectManager().runMessage(entry.message);

        // Clear the buffer
        _receivedData = _receivedData.sublist(messageSize + 4);
        notifyListeners();
      } else {
        // Incomplete message, wait for more data
        break;
      }
    }
  }

  void sendMessage(Message message) async {
    if (_writeCharacteristic == null || !_isConnected) {
      print("Error: Not connected to a device.");
      return;
    }

    try {
      // 1. Convert Message to Uint8List
      int totalLength = 0;
      for (var list in message.segments) {
        totalLength += list.length;
      }

      // Create a new Uint8List with the total length.
      Uint8List messageData = Uint8List(totalLength);

      // Copy the data from each list into the combined list.
      int offset = 0;
      for (var list in message.segments) {
        messageData.setRange(offset, offset + list.length, list);
        offset += list.length;
      } // Assuming you have this method in your Message class

      // 2. Calculate Message Length
      int messageLength = messageData.length;

      // 3. Create Length Prefix
      ByteData lengthBytes = ByteData(4);
      lengthBytes.setUint32(0, messageLength, Endian.little);
      Uint8List lengthPrefix = lengthBytes.buffer.asUint8List();

      // 4. Combine Length and Message
      Uint8List combinedData =
          Uint8List(lengthPrefix.length + messageData.length);
      combinedData.setRange(0, lengthPrefix.length, lengthPrefix);
      combinedData.setRange(
          lengthPrefix.length, combinedData.length, messageData);

      // 5. Send Data
      await UniversalBle.write(
        _device!.deviceId,
        _writeCharacteristicServiceUuid!,
        _writeCharacteristic!.uuid,
        combinedData,
        withoutResponse: _writeCharacteristic!.properties.contains(CharacteristicProperty.writeWithoutResponse),
      );

      QueueEntry entry = QueueEntry(
          message: message,
          timestamp: DateTime.now(),
          direction: MessageDirection.output);
      MessageQueue().addEntry(entry);
    } catch (error) {
      print("Error sending message: $error");
      // Handle the error appropriately (e.g., disconnect, retry, etc.)
    }
  }

  void disconnect() {
    if (_device != null) {
      UniversalBle.disconnect(_device!.deviceId);
    }
  }

  // Set the selected device
  void setSelectedDevice(BleDevice? selectedDevice) {
    if (_device?.deviceId == selectedDevice?.deviceId) {
      if (!_isConnected) {
        connect();
      }
      return;
    }
    if (isConnected) {
      disconnect();
    }
    _device = selectedDevice;
    notifyListeners();
    if (_device != null) {
      connect();
    }
  }
}
