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
  ConnectionType get connectionType => _connectionType;

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
    if (selectedDevice == null || _isConnecting || _isConnected) return;

    _isConnecting = true;
    notifyListeners();

    try {
      if (_connectionType == ConnectionType.ble) {
        await UniversalBle.connect(_bleDevice!.deviceId);
      } else if (_connectionType == ConnectionType.uart) {
        if (Platform.isAndroid) return;

        _serialPort = SerialPort(_serialPortName!);

        if (!_serialPort!.openReadWrite()) {
          throw Exception("Failed to open port: ${SerialPort.lastError}");
        }

        // --- FIXED CONFIGURATION ---
        final config = SerialPortConfig();
        config.baudRate = 115200;
        config.bits = 8;
        config.stopBits = 1;
        config.parity = SerialPortParity.none;

        // Set DTR and RTS to 0 (Off) to stop the ESP32/Arduino Reset trigger
        config.dtr = 0;
        config.rts = 0;

        // Set Flow Control to None (0)
        config.setFlowControl(SerialPortFlowControl.none);

        // Apply the configuration to the active port
        _serialPort!.config = config;

        _isConnected = true;
        _isConnecting = false;
        _startSerialPortListen();
        notifyListeners();
      }
    } catch (error) {
      _isConnecting = false;
      _isConnected = false;
      print("Connection Error: $error");
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
    _rawBuffer.addAll(value);

    while (_rawBuffer.length >= 64) {
      if (_rawBuffer[0] == 0xFA) {
        int receivedCrc = _rawBuffer[1];
        int dataLen = _rawBuffer[2];

        if (dataLen <= 60) {
          int footerIdx = 3 + dataLen;

          // FIX: Match C++ range (starts at index 2, length is dataLen + 1)
          final crcInput = _rawBuffer.sublist(2, 3 + dataLen);
          int calculatedCrc = _calculateCrc8(crcInput);

          if (receivedCrc == calculatedCrc && _rawBuffer[footerIdx] == 0xBF) {
            final payload = Uint8List.fromList(_rawBuffer.sublist(3, 3 + dataLen));
            _handleReceivedData(payload);

            _rawBuffer.removeRange(0, 64);
            continue;
          }
        }
        _rawBuffer.removeAt(0); // Validation failed
      } else {
        _rawBuffer.removeAt(0); // Not a header
      }
    }
  }

  String toHexLog(Uint8List data) {
    return data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  void _handleReceivedData(Uint8List value) {
    // RAW LOG: Every byte coming off the wire
    print('BLE/UART IN <<<: ${toHexLog(value)}');

    Future.microtask(() {
      final builder = BytesBuilder(copy: false);
      builder.add(_receivedData);
      builder.add(value);
      _receivedData = builder.takeBytes();

      _processMessage();
      notifyListeners();
    });
  }
  DateTime? _lastReceiveTime;
  void _processMessage() {
    _lastReceiveTime = DateTime.now();
    while (_receivedData.length >= 2) {
      final byteData = ByteData.sublistView(_receivedData);


      // Read the 16-bit payload length (Little Endian)
      final int payloadLen = byteData.getUint16(0, Endian.little);
      final int totalFrameSize = payloadLen + 2;

      // Check if the buffer has caught up to the header's requirements
      if (_receivedData.length >= totalFrameSize) {

        final Uint8List payload = _receivedData.sublist(2, totalFrameSize);

        // --- FRAMING LOGS ---
        // Shows: [Header Value] -> [Actual Bytes Consumed]
        //print('📦 FRAME: Header claims $payloadLen bytes. Total consumed: $totalFrameSize');
        //print('   Data: ${toHexLog(payload)}');

        // 3. Execute Logic
        ObjectManager().runMessage(payload);

        // 4. Slice the processed message out of the buffer
        _receivedData = _receivedData.sublist(totalFrameSize);
      } else {
        // If we've been waiting for a full frame for more than 1 second, clear it
        if (_lastReceiveTime != null &&
            DateTime.now().difference(_lastReceiveTime!).inMilliseconds > 1000) {
          print("⚠️ Protocol Desync: Clearing stuck buffer (${_receivedData.length} bytes)");
          _receivedData = Uint8List(0);
        }
        // Fragmentation Log: Helpful to see if a packet is "stuck" mid-stream
        //print('⏳ INCOMPLETE: Need $totalFrameSize bytes, but only have ${_receivedData.length} in buffer.');
        break;
      }
    }
  }

  void sendMessage(Uint8List payload) async {
    if (!_isConnected) return;

    try {
      // 1. GLOBAL FRAMING
      // The length header represents the size of the payload ONLY.
      final int payloadSize = payload.length;
      final int framedSize = payloadSize + 2;
      final Uint8List framedData = Uint8List(framedSize);
      final ByteData bd = ByteData.view(framedData.buffer);

      // Write 2-byte length (Little Endian) + the actual payload
      bd.setUint16(0, payloadSize, Endian.little);
      framedData.setRange(2, framedSize, payload);

      print('SEND [Payload: $payloadSize, Total: $framedSize]: ${toHexLog(framedData)}');

      // 2. BLE TRANSMISSION
      if (_connectionType == ConnectionType.ble) {
        if (_writeCharacteristic == null) return;

        await UniversalBle.write(
          _bleDevice!.deviceId,
          _writeCharacteristicServiceUuid!,
          _writeCharacteristic!.uuid,
          framedData,
          withoutResponse: _writeCharacteristic!.properties.contains(CharacteristicProperty.writeWithoutResponse),
        );
      }

      // 3. UART TRANSMISSION
      else if (_connectionType == ConnectionType.uart) {
        if (Platform.isAndroid || _serialPort == null || !_serialPort!.isOpen) return;

        // Wakeup Sequence (0xAA is better for auto-baud detection)
        _serialPort!.write(Uint8List.fromList([0xAA, 0xAA, 0xAA, 0xAA]));
        await Future.delayed(const Duration(milliseconds: 5));

        const int maxDataPerPacket = 60; // Max payload per 64-byte hardware frame
        int offset = 0;

        while (offset < framedData.length) {
          final int remaining = framedData.length - offset;
          final int toCopy = (remaining > 60) ? 60 : remaining;

          final packet = Uint8List(64);
          packet[0] = 0xFA;
          packet[2] = toCopy;

          final Uint8List chunkData = framedData.sublist(offset, offset + toCopy);
          packet.setRange(3, 3 + toCopy, chunkData);

          // FIX: Include the Length Byte (index 2) in the CRC calculation
          // We create a temporary list of [length, ...data] to match C++ 'packet + 2'
          final crcInput = Uint8List.fromList([toCopy, ...chunkData]);
          packet[1] = _calculateCrc8(crcInput);

          packet[3 + toCopy] = 0xBF;

          _serialPort!.write(packet);
          await Future.delayed(const Duration(milliseconds: 5)); // Increased for stability
          offset += toCopy;
        }
      }
    } catch (error) {
      print("Error sending message: $error");
    }
  }

  void disconnect() {
    _rawBuffer.clear();
    _receivedData = Uint8List(0); // Clear the reconstructed message buffer too

    if (_isConnected) {
      if (_connectionType == ConnectionType.ble && _bleDevice != null) {
        UniversalBle.disconnect(_bleDevice!.deviceId);
      } else if (_connectionType == ConnectionType.uart && _serialPort != null) {
        if (Platform.isAndroid) return;
        _serialPortSubscription?.cancel();
        _serialPort?.flush(); // Clear hardware buffers
        _serialPort?.close();
        _serialPort = null;
        _serialPortSubscription = null;
      }
    }
    _isConnected = false;
    _isConnecting = false;
    notifyListeners();
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
