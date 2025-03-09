import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      _updateBluetoothState(state);
    });
  }

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  final List<BluetoothService> _services = [];

  BluetoothAdapterState _bluetoothState = BluetoothAdapterState.unknown;
  bool _isConnected = false;
  bool _isConnecting = false;

  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  BluetoothAdapterState get bluetoothState => _bluetoothState;
  get selectedDevice => _device;

  Uint8List _receivedData = Uint8List(0);

  void _updateBluetoothState(BluetoothAdapterState state) {
    _bluetoothState = state;
    notifyListeners();
  }

  Future<void> requestEnableBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) {
      return;
    }
    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        print("Error turning on Bluetooth: $e");
      }
    }
  }

  Future<void> startScan() async {
    if (_scanSubscription != null) {
      return;
    }
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
    });
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
  }

  Future<void> stopScan() async {
    if (_scanSubscription == null) {
      return;
    }
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
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
      await _device!.connect();
      _isConnected = true;
      _isConnecting = false;
      _services.addAll(await _device!.discoverServices());
      _findCharacteristics();
      notifyListeners();
    } catch (error) {
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
    }
  }

  void _findCharacteristics() {
    for (BluetoothService service in _services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write && _writeCharacteristic == null) {
          _writeCharacteristic = characteristic;
        }
        if (characteristic.properties.notify && _notifyCharacteristic == null) {
          _notifyCharacteristic = characteristic;
          _startNotify();
        }
      }
    }
  }

  void _startNotify() {
    if (_notifyCharacteristic == null) {
      return;
    }
    _notifyCharacteristic!.setNotifyValue(true);
    _characteristicSubscription = _notifyCharacteristic!.lastValueStream.listen(_onDataReceived,);
  }

  void _onDataReceived(List<int> data) {
    _notifyCharacteristic!.lastValueStream.drain();
    // Append the new data to the received data buffer
    final newData = Uint8List(_receivedData.length + data.length);
    newData.setRange(0, _receivedData.length, _receivedData);
    newData.setRange(_receivedData.length, newData.length, data);
    _receivedData = newData;

    // Process the message buffer
    _processMessage();
    notifyListeners();
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

  void sendMessage(Message message) async{
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
      Uint8List combinedData = Uint8List(lengthPrefix.length + messageData.length);
      combinedData.setRange(0, lengthPrefix.length, lengthPrefix);
      combinedData.setRange(lengthPrefix.length, combinedData.length, messageData);

      // 5. Send Data
      if (_writeCharacteristic!.properties.writeWithoutResponse) {
        // Use writeWithoutResponse if supported
        await _writeCharacteristic!.write(combinedData, withoutResponse: true);
    print("Message sent without response.");
    } else if (_writeCharacteristic!.properties.write) {
    // Use regular write if writeWithoutResponse is not supported
    await _writeCharacteristic!.write(combinedData, withoutResponse: false);
    print("Message sent with response.");
    } else {
    print("Error: The characteristic does not support writing.");
    return;
    }

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
    _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    _device?.disconnect();
    _isConnected = false;
    _isConnecting = false;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _services.clear();
    _receivedData = Uint8List(0);
    notifyListeners();
  }

  // Set the selected device
  void setSelectedDevice(BluetoothDevice? selectedDevice) {
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
