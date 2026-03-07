import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  BluetoothDevice? connectedDevice;
  StreamSubscription<List<int>>? _dataSubscription;

  // Threshold for detecting a laser break (spike in voltage)
  static const double spikeThreshold =
      2.5; // Example value, should be configurable

  final _runDataController = StreamController<double>.broadcast();
  Stream<double> get runDataStream => _runDataController.stream;

  final _gateCrossingController = StreamController<int>.broadcast();
  Stream<int> get gateCrossingStream => _gateCrossingController.stream;

  List<double> currentRunVoltages = [];
  List<int> gateTimes = [];
  DateTime? startTime;

  Future<void> startScan() async {
    // Note: The license parameter is required but seems to be an arbitrary string for some older plugins.
    // If using the latest version of flutter_blue_plus, this might not be required or might take a different form.
    // Since the IDE requires it, providing a blank placeholder.
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect();
    connectedDevice = device;

    // Discover services and find the characteristic for data
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          await characteristic.setNotifyValue(true);
          _dataSubscription = characteristic.lastValueStream.listen((value) {
            _handleIncomingData(value);
          });
        }
      }
    }
  }

  void _handleIncomingData(List<int> value) {
    // Assuming data is a float sent as bytes or a simple int
    // This part depends on the specific hardware implementation
    // For now, let's assume it's a single byte for simplicity or a 2-byte int
    double voltage = value.isNotEmpty
        ? value[0] / 51.0
        : 0.0; // Mock mapping to 0-5V

    currentRunVoltages.add(voltage);
    _runDataController.add(voltage);

    if (voltage > spikeThreshold) {
      _processSpike();
    }
  }

  void _processSpike() {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (startTime == null) {
      startTime = DateTime.now();
      gateTimes.add(0);
      _gateCrossingController.add(0);
    } else {
      int offset = now - startTime!.millisecondsSinceEpoch;
      // Simple debounce: only record a gate if it's been at least 500ms since the last one
      if (gateTimes.isEmpty || offset - gateTimes.last > 500) {
        gateTimes.add(offset);
        _gateCrossingController.add(offset);
      }
    }
  }

  void resetRun() {
    currentRunVoltages.clear();
    gateTimes.clear();
    startTime = null;
  }

  void dispose() {
    _dataSubscription?.cancel();
    _runDataController.close();
    _gateCrossingController.close();
  }
}
