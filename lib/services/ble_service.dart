import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'data_processing_service.dart';

class BleService {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? _targetCharacteristic;
  StreamSubscription<List<int>>? _lastValueSubscription;

  // HM-10 / CC2541 Common UUIDs
  static const String serviceUuid = "0000FFE0-0000-1000-8000-00805F9B34FB";
  static const String characteristicUuid = "0000FFE1-0000-1000-8000-00805F9B34FB";

  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  Stream<BluetoothConnectionState> get connectionState => _connectionStateController.stream;

  final _isScanningController = StreamController<bool>.broadcast();
  Stream<bool> get isScanning => _isScanningController.stream;

  final _timingDataController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get timingDataStream => _timingDataController.stream;

  BleService() {
    FlutterBluePlus.isScanning.listen((scanning) {
      _isScanningController.add(scanning);
    });
  }

  Future<void> startScan() async {
    if (await FlutterBluePlus.isSupported == false) return;
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      connectedDevice = device;
      _connectionStateController.add(BluetoothConnectionState.connected);

      // Listen for disconnection
      device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevice = null;
          _targetCharacteristic = null;
          _lastValueSubscription?.cancel();
        }
      });

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toUpperCase() == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == characteristicUuid) {
              _targetCharacteristic = characteristic;
              await _setupNotifications(characteristic);
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Connection error: $e");
      rethrow;
    }
  }

  Future<void> _setupNotifications(BluetoothCharacteristic characteristic) async {
    if (characteristic.properties.notify) {
      await characteristic.setNotifyValue(true);
      _lastValueSubscription = characteristic.lastValueStream.listen((value) {
        _handleIncomingRawData(value);
      });
    }
  }

  void _handleIncomingRawData(List<int> value) {
    if (value.isEmpty) return;
    String rawString = utf8.decode(value);
    debugPrint("Received BLE data: $rawString");

    try {
      if (rawString.contains(',')) {
        List<int> offsets = DataProcessingService.parseNodeTimingData(rawString);
        _timingDataController.add(offsets);
      }
    } catch (e) {
      debugPrint("Error parsing timing data: $e");
    }
  }

  Future<void> sendStartCommand() async {
    await _writeString("START");
  }

  Future<void> sendStopCommand() async {
    await _writeString("STOP");
  }

  Future<void> triggerWifiSync() async {
    await _writeString("SYNC_WIFI");
  }

  Future<void> _writeString(String data) async {
    if (_targetCharacteristic == null) return;
    try {
      await _targetCharacteristic!.write(utf8.encode(data));
    } catch (e) {
      debugPrint("Write error: $e");
    }
  }

  Future<void> disconnect() async {
    await connectedDevice?.disconnect();
    connectedDevice = null;
    _targetCharacteristic = null;
    _lastValueSubscription?.cancel();
  }

  void dispose() {
    _connectionStateController.close();
    _isScanningController.close();
    _timingDataController.close();
    _lastValueSubscription?.cancel();
  }
}
