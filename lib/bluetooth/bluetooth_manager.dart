import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import '../message/message.dart';
import '../message/message_queue.dart';
import '../object/object_manager.dart';

enum ConnectionType { ble, uart }

const String UART_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
const String CHARACTERISTIC_UUID_RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; // For Writing
const String CHARACTERISTIC_UUID_TX = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; // For Notifying

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
        if (_connectionType != ConnectionType.ble || deviceId != _bleDevice?.deviceId) return;

        _isConnected = isConnected;
        _isConnecting = false;

        if (_isConnected) {
          try {
            final services = await UniversalBle.discoverServices(_bleDevice!.deviceId);
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

  ConnectionType _connectionType = ConnectionType.ble;

  // BLE specific variables
  BleDevice? _bleDevice;
  BleCharacteristic? _writeCharacteristic;
  String? _writeCharacteristicServiceUuid;
  BleCharacteristic? _notifyCharacteristic;
  String? _notifyCharacteristicServiceUuid;
  final List<BleService> _services = [];

  // UART specific variables
  SerialPort? _serialPort;
  String? _serialPortName;
  StreamSubscription<Uint8List>? _serialPortSubscription;


  AvailabilityState _bluetoothState = AvailabilityState.unsupported;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isScanning = false;

  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  AvailabilityState get bluetoothState => _bluetoothState;

  dynamic get selectedDevice => _connectionType == ConnectionType.ble ? _bleDevice : _serialPortName;

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
    if (selectedDevice == null || _isConnecting || _isConnected) {
      return;
    }
    _isConnecting = true;
    notifyListeners();

    try {
      if (_connectionType == ConnectionType.ble) {
        await UniversalBle.connect(_bleDevice!.deviceId);
      } else if (_connectionType == ConnectionType.uart) {
        if (Platform.isAndroid) {
          print("UART not supported on Android");
          return;
        }
        _serialPort = SerialPort(_serialPortName!);
        if (!_serialPort!.openReadWrite()) {
          print("Failed to open serial port: ${SerialPort.lastError}");
          throw Exception("Failed to open serial port");
        }
        _isConnected = true;
        _isConnecting = false;
        _startSerialPortListen();
        notifyListeners();
      }
    } catch (error) {
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
    }
  }

  Future<void> _findCharacteristics() async {
    try {
      final mtu = await UniversalBle.requestMtu(_bleDevice!.deviceId, 512);
      print('Negotiated MTU: $mtu');
    } catch (e) {
      print('Error requesting MTU: $e');
    }

    print("Discovering specific UART characteristics...");

    for (BleService service in _services) {
      // Only look inside the UART Service
      if (service.uuid.toLowerCase() == UART_SERVICE_UUID) {

        for (BleCharacteristic characteristic in service.characteristics) {
          String charUuid = characteristic.uuid.toLowerCase();

          // Match the RX characteristic (for writing data TO the device)
          if (charUuid == CHARACTERISTIC_UUID_RX) {
            _writeCharacteristic = characteristic;
            _writeCharacteristicServiceUuid = service.uuid;
            print('Matched Write (RX): ${characteristic.uuid}');
          }

          // Match the TX characteristic (for receiving data FROM the device)
          if (charUuid == CHARACTERISTIC_UUID_TX) {
            _notifyCharacteristic = characteristic;
            _notifyCharacteristicServiceUuid = service.uuid;
            print('Matched Notify (TX): ${characteristic.uuid}');
            _startNotify();
          }
        }
      }
    }

    if (_writeCharacteristic == null || _notifyCharacteristic == null) {
      print("Warning: Could not find all UART characteristics.");
    }
  }

  void _startNotify() async {
    if (_notifyCharacteristic == null) {
      return;
    }
    await UniversalBle.subscribeNotifications(
      _bleDevice!.deviceId,
      _notifyCharacteristicServiceUuid!,
      _notifyCharacteristic!.uuid,
    );
    UniversalBle.onValueChange = _onBleDataReceived;
  }

  void _startSerialPortListen() {
    if (Platform.isAndroid || _serialPort == null || !_serialPort!.isOpen) return;

    final reader = SerialPortReader(_serialPort!);
    _serialPortSubscription = reader.stream.listen(_onUartDataReceived, onError: (error) {
        print("Serial port error: $error");
        disconnect();
    }, onDone: (){
        print("Serial port closed");
        disconnect();
    });
  }

  void _onBleDataReceived(String deviceId, String characteristicId, Uint8List value) {
    // Filter notifications to only the characteristic we are interested in.
    if (characteristicId != _notifyCharacteristic?.uuid) {
      return;
    }
    _handleReceivedData(value);
  }

  final List<int> _rawBuffer = [];

  int _calculateCrc8(List<int> data) {
    int crc = 0x00;
    for (int b in data) {
      crc ^= b;
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x80) != 0) {
          crc = ((crc << 1) ^ 0x31) & 0xFF;
        } else {
          crc = (crc << 1) & 0xFF;
        }
      }
    }
    return crc;
  }

  void _onUartDataReceived(Uint8List value) {
    if (Platform.isAndroid) return;
    _rawBuffer.addAll(value);

    while (_rawBuffer.length >= 64) {
      if (_rawBuffer[0] == 0xFA) {
        int receivedCrc = _rawBuffer[1];
        int dataLen = _rawBuffer[2];

        if (dataLen <= 60) {
          // 1. Verify CRC (Calculated over Len + Data)
          int calculatedCrc = _calculateCrc8(_rawBuffer.sublist(2, 3 + dataLen));

          if (receivedCrc == calculatedCrc) {
            // 2. Verify Footer
            int footerIdx = 3 + dataLen;
            if (_rawBuffer[footerIdx] == 0xBF) {

              // SUCCESS
              final payload = Uint8List.fromList(_rawBuffer.sublist(3, 3 + dataLen));
              _handleReceivedData(payload);

            } else {
              print("Corruption: Footer BF missing at $footerIdx");
            }
          } else {
            print("Corruption: CRC Mismatch (Expected $receivedCrc, got $calculatedCrc)");
          }
        }

        _rawBuffer.removeRange(0, 64);
      } else {
        _rawBuffer.removeAt(0); // Sync hunt
      }
    }
  }

  void _handleReceivedData(Uint8List value){
    //print('Incoming <<<: ${value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ')}');
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
    if (!_isConnected) {
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

      //print('Outgoing >>>: ${combinedData.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ')}');

      // 5. Send Data
      if (_connectionType == ConnectionType.ble) {
        if (_writeCharacteristic == null) return;
        await UniversalBle.write(
          _bleDevice!.deviceId,
          _writeCharacteristicServiceUuid!,
          _writeCharacteristic!.uuid,
          combinedData,
          withoutResponse: _writeCharacteristic!.properties.contains(CharacteristicProperty.writeWithoutResponse),
        );
      } else if (_connectionType == ConnectionType.uart) {
        if (Platform.isAndroid || _serialPort == null || !_serialPort!.isOpen) return;

        const int maxData = 60;
        int offset = 0;

        while (offset < combinedData.length) {
          final packet = Uint8List(64); // Automatically zero-padded
          int toCopy = (combinedData.length - offset > maxData) ? maxData : combinedData.length - offset;

          packet[0] = 0xFA;
          packet[2] = toCopy;

          // Copy payload
          List.copyRange(packet, 3, combinedData, offset, offset + toCopy);

          packet[3 + toCopy] = 0xBF;

          // CRC over [Len + Data]
          packet[1] = _calculateCrc8(packet.sublist(2, 3 + toCopy));

          _serialPort!.write(packet);
          offset += toCopy;
        }
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
    if (_isConnected) {
       if (_connectionType == ConnectionType.ble && _bleDevice != null) {
        UniversalBle.disconnect(_bleDevice!.deviceId);
      } else if (_connectionType == ConnectionType.uart && _serialPort != null) {
        if (Platform.isAndroid) return;
        _serialPortSubscription?.cancel();
        _serialPort?.close();
        _serialPort = null;
        _serialPortSubscription = null;
        _isConnected = false;
        notifyListeners();
      }
    }
  }

  void setSelectedDevice(dynamic device) {
     if (device is BleDevice) {
      if (_bleDevice?.deviceId == device.deviceId) {
        if (!_isConnected && !_isConnecting) {
          connect();
        }
        return;
      }
      if (isConnected) {
        disconnect();
      }
      _connectionType = ConnectionType.ble;
      _bleDevice = device;
      _serialPortName = null;
    } else if (device is String) {
      if (Platform.isAndroid) return;
      if (_serialPortName == device) {
        if (!_isConnected && !_isConnecting) {
          connect();
        }
        return;
      }
      if (isConnected) {
        disconnect();
      }
      _connectionType = ConnectionType.uart;
      _serialPortName = device;
      _bleDevice = null;
    } else {
      return; // Or throw an error
    }

    notifyListeners();
    if (selectedDevice != null) {
      connect();
    }
  }
}
