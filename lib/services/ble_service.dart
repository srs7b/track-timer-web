import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BleDeviceStatus { disconnected, connecting, connected, ready, error }

class BleService {

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? _targetCharacteristic;
  StreamSubscription<List<int>>? _lastValueSubscription;
  Timer? _pollTimer;
  
  // Storage for hits during a single run
  final List<int> _sessionBuffer = [];
  void _addHit(int ms) {
    _sessionBuffer.add(ms);
    _hitCountController.add(_sessionBuffer.length);
  }
  // Deduplication for redundant Notify vs Read hits
  final Set<String> _seenHits = {};

  // Common HM-10 / Custom Arduino UUID variants
  static const List<String> serviceUuidVariants = [
    "00001234-0000-1000-8000-00805F9B34FB", // Custom Arduino (from user code)
    "0000FFE0-0000-1000-8000-00805F9B34FB", // Standard HM-10
    "0000FFF0-0000-1000-8000-00805F9B34FB", // Clone Variant A
  ];

  static const List<String> charUuidVariants = [
    "00005678-0000-1000-8000-00805F9B34FB", // Custom Arduino (from user code)
    "0000FFE1-0000-1000-8000-00805F9B34FB",
    "0000FFF1-0000-1000-8000-00805F9B34FB",
  ];

  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  Stream<BluetoothConnectionState> get connectionState => _connectionStateController.stream;

  final _isScanningController = StreamController<bool>.broadcast();
  Stream<bool> get isScanning => _isScanningController.stream;

  final _timingDataController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get timingDataStream => _timingDataController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusMessage => _statusController.stream;

  final _deviceStatusController = StreamController<BleDeviceStatus>.broadcast();
  Stream<BleDeviceStatus> get deviceStatus => _deviceStatusController.stream;

  DateTime? lastHeartbeat;
  final _heartbeatController = StreamController<DateTime>.broadcast();
  Stream<DateTime> get heartbeatStream => _heartbeatController.stream;

  final _hitCountController = StreamController<int>.broadcast();
  Stream<int> get hitCount => _hitCountController.stream;

  BleDeviceStatus _currentStatus = BleDeviceStatus.disconnected;
  BleDeviceStatus get currentStatus => _currentStatus;

  void _updateStatus(BleDeviceStatus status) {
    _currentStatus = status;
    _deviceStatusController.add(status);
  }

  BleService() {
    FlutterBluePlus.isScanning.listen((scanning) {
      _isScanningController.add(scanning);
    });
  }

  Future<void> startScan() async {
    if (await FlutterBluePlus.isSupported == false) return;
    _statusController.add("BLE: SCANNING FOR TRACKNODE...");
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      // Web Bluetooth REQUIREMENT: Services must be explicitly whitelisted
      // even if we are filtering by name.
      withServices: serviceUuidVariants.map((u) => Guid(u)).toList(),
      withNames: ["TrackNode", "HMSoft", "BT05", "MLT-BT05"],
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  /// Phase 1: Establish the raw GATT connection
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _statusController.add("PHASE 1: CONNECTING...");
      _updateStatus(BleDeviceStatus.connecting);
      await device.connect();
      connectedDevice = device;
      _connectionStateController.add(BluetoothConnectionState.connected);
      _updateStatus(BleDeviceStatus.connected);
      _statusController.add("PHASE 1: CONNECTION OK");

      // Listen for disconnection
      device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevice = null;
          _targetCharacteristic = null;
          _lastValueSubscription?.cancel();
          _statusController.add("BLE: DISCONNECTED");
          _updateStatus(BleDeviceStatus.disconnected);
          _stopPolling();
          if (_sessionBuffer.isNotEmpty) finalizeSession();
        }
      });
    } catch (e) {
      _statusController.add("PHASE 1 ERROR: ${e.toString().split('|').last.trim()}");
      debugPrint("Connection error: $e");
      rethrow;
    }
  }

  /// Phase 2 & 3: Discover services and initialize the data stream
  Future<void> prepareHardware() async {
    if (connectedDevice == null) return;
    
    try {
      // Phase 2: Service Discovery
      _statusController.add("PHASE 2: DISCOVERING SERVICES...");
      await Future.delayed(const Duration(milliseconds: 1000)); // Increased breather
      List<BluetoothService> services = await connectedDevice!.discoverServices();
      _statusController.add("PHASE 2: FOUND ${services.length} SERVICES");
      
      bool found = false;
      final targetServices = serviceUuidVariants.map((v) => Guid(v)).toList();
      final targetChars = charUuidVariants.map((v) => Guid(v)).toList();

      for (var service in services) {
        _statusController.add("DEBUG: SERVICE ${service.uuid}");
        if (targetServices.contains(service.uuid)) {
          _statusController.add("PHASE 2: COMPATIBLE SERVICE FOUND");
          for (var characteristic in service.characteristics) {
            if (targetChars.contains(characteristic.uuid)) {
              _statusController.add("PHASE 2: DATA CHANNEL LOCATED");
              _targetCharacteristic = characteristic;
              
              String props = "";
              if (characteristic.properties.read) props += "R ";
              if (characteristic.properties.write) props += "W ";
              if (characteristic.properties.notify) props += "N ";
              if (characteristic.properties.indicate) props += "I ";
              _statusController.add("PROPERTIES [$props]");

              found = true;
              break;
            }
          }
        }
        if (found) break;
      }

      if (found && _targetCharacteristic != null) {
        _statusController.add("PHASE 2: SERVICE HANDSHAKE OK");
        
        // OFFICIAL SEQUENCE: Wait for Chrome's GATT cache to stabilize (3s)
        _statusController.add("PHASE 3: COOLDOWN (STABILIZING CACHE)...");
        await Future.delayed(const Duration(seconds: 3));

        // Step A: Background Subscription (Don't wait, since it often fails on Web)
        _statusController.add("PHASE 3.1: STARTING DATA LISTENER (BG)...");
        _setupNotificationsWithRetry(_targetCharacteristic!);
        
        // Step B: Manual Read (The new primary proof of life)
        _statusController.add("PHASE 3.2: VERIFYING GATT PIPE (READ)...");
        String? initialValue = await readData();
        bool readSuccess = initialValue != null;

        if (readSuccess) {
          _updateStatus(BleDeviceStatus.ready);
          _statusController.add("HARDWARE READY (POLLING MODE)");
          _startPolling(); 
        } else {
          _statusController.add("PHASE 3 ERROR: GATT READ FAILED");
          _updateStatus(BleDeviceStatus.error);
        }
      } else {
        _statusController.add("PHASE 2 ERROR: NO COMPATIBLE SERVICES");
        _updateStatus(BleDeviceStatus.error);
      }
    } catch (e) {
      _statusController.add("PHASE 2/3 ERROR: ${e.toString().split('|').last.trim()}");
      _updateStatus(BleDeviceStatus.error);
      debugPrint("Preparation error: $e");
    }
  }

  Future<bool> _setupNotificationsWithRetry(BluetoothCharacteristic characteristic, {int retries = 3}) async {
    if (!characteristic.properties.notify) return false;

    // Attach stream listener immediately. Even if the 'enable' call throws an error,
    // Web Bluetooth sometimes starts the stream anyway once we've touched the char.
    _statusController.add("PHASE 3: ATTACHING DATA LISTENER...");
    _lastValueSubscription?.cancel();
    _lastValueSubscription = characteristic.lastValueStream.listen((value) {
      _handleIncomingRawData(value);
    });

    for (int i = 0; i < retries; i++) {
      try {
        _statusController.add("PHASE 3: ENABLING NOTIFICATIONS (TRY ${i + 1})...");
        await characteristic.setNotifyValue(true);
        _statusController.add("PHASE 3: STREAM READY");
        return true; 
      } catch (e) {
        String error = e.toString().toLowerCase();
        // If it's already enabled or busy but we have a listener, 
        // we might already be getting data.
        if (error.contains("already") || error.contains("in progress")) {
          _statusController.add("PHASE 3: BUSY (OPTIMISTIC SUCCESS)");
          return true; 
        }
        
        if (i == retries - 1) {
          _statusController.add("PHASE 3: HANDSHAKE TIMEOUT.");
        } else {
          _statusController.add("PHASE 3: BUSY, RETRYING...");
          await Future.delayed(Duration(milliseconds: 1000 * (i + 1))); 
        }
      }
    }
    return false;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (currentStatus == BleDeviceStatus.ready || currentStatus == BleDeviceStatus.connected) {
        readData();
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<String?> readData() async {
    if (_targetCharacteristic == null) {
      _statusController.add("READ ERROR: NO DATA CHANNEL");
      return null;
    }
    
    try {
      _statusController.add("BLE: PERFORMING MANUAL READ...");
      List<int> value = await _targetCharacteristic!.read();
      String decoded = utf8.decode(value).trim();
      _statusController.add("READ SUCCESS: $decoded");
      return decoded;
    } catch (e) {
      debugPrint("Read error: $e");
      _statusController.add("READ ERROR");
      return null;
    }
  }

  void _handleIncomingRawData(List<int> value) {
    if (value.isEmpty) return;
    String rawString = utf8.decode(value).trim();
    
    // Deduplicate: If we just saw this exact message (e.g. from a poll vs notify), skip
    if (_seenHits.contains(rawString)) return;
    _seenHits.add(rawString);
    // Keep set size small (last 20 messages)
    if (_seenHits.length > 20) _seenHits.remove(_seenHits.first);

    // Internal status messages from firmware
    if (rawString == "PING" || rawString == "CONNECTED") {
      lastHeartbeat = DateTime.now();
      _heartbeatController.add(lastHeartbeat!);
      // Reduced console noise (don't statusController.add unless UI needs text)
      // _statusController.add("STATUS: $rawString"); 
      return;
    }

    _statusController.add("RECEIVED: $rawString");
    debugPrint("BLE DATA: $rawString");

    try {
      // Handle comma-separated node data (e.g. "1,4500000")
      if (rawString.contains(',')) {
        List<String> parts = rawString.split(',');
        if (parts.length >= 2) {
          int? timestamp = int.tryParse(parts[1].trim());
          if (timestamp != null) {
            // 1. Drop startup artifacts or extreme noise (e.g., hits under 100ms)
            if (timestamp < 100000) {
              _statusController.add("NOISE FILTERED: $rawString");
              return;
            }

            int ms = (timestamp / 1000).round();
            
            // 2. Blanking Period: Drop redundant triggers (e.g., trailing legs/arms)
            // If this hit is within 500ms of the previous hit, it's likely the same gate crossing.
            if (_sessionBuffer.isNotEmpty) {
              int lastMs = _sessionBuffer.last;
              if ((ms - lastMs).abs() < 500) {
                _statusController.add("DUPLICATE DROPPED: $rawString");
                return;
              }
            }

            _addHit(ms);
          }
        }
      }
    } catch (e) {
      debugPrint("Data parse error: $e");
    }
  }

  /// Convert the current buffer of hits into a finalized run event
  void finalizeSession() {
    if (_sessionBuffer.isEmpty) return;
    
    _statusController.add("FINALIZING SESSION: ${_sessionBuffer.length} HITS");
    
    // Sort and normalize times relative to the first hit
    _sessionBuffer.sort();
    int baseTime = _sessionBuffer.first;
    List<int> normalized = _sessionBuffer.map((t) => t - baseTime).toList();
    
    if (normalized.length >= 2) {
      _timingDataController.add(normalized);
    }
    
    _sessionBuffer.clear();
    _hitCountController.add(0);
    _seenHits.clear();
  }

  Future<void> sendStartCommand() async {
    _statusController.add("BLE: INITIATING START TRIGGER...");
    _sessionBuffer.clear();
    _hitCountController.add(0);
    _seenHits.clear();
    await _writeString("START");
    _statusController.add("BLE: START ACKNOWLEDGED");
  }

  Future<void> sendStopCommand() async {
    finalizeSession();
    await _writeString("STOP");
  }

  Future<void> triggerWifiSync() async {
    await _writeString("SYNC_WIFI");
  }

  Future<void> _writeString(String data) async {
    if (_targetCharacteristic == null) {
      _statusController.add("BLE: ERROR - NO DATA CHANNEL");
      return;
    }
    
    try {
      _statusController.add("BLE: SENDING COMMAND: $data");
      // Phase A: Write the command to wake up the board (Request response for confirmation)
      await _targetCharacteristic!.write(utf8.encode(data), withoutResponse: false);
      
      // Phase B: Late-Binding Notifications (Legacy logic - now handled in prepareHardware)
      // but kept for fallback or if notifications dropped
      if (data == "START" && _lastValueSubscription == null) {
        await _setupNotificationsWithRetry(_targetCharacteristic!);
      }
    } catch (e) {
      debugPrint("Write error: $e");
      _statusController.add("BLE: WRITE ERROR");
    }
  }

  Future<void> disconnect() async {
    await connectedDevice?.disconnect();
    connectedDevice = null;
    _targetCharacteristic = null;
    _lastValueSubscription?.cancel();
    _lastValueSubscription = null;
    _updateStatus(BleDeviceStatus.disconnected);
    _stopPolling();
  }

  void dispose() {
    _stopPolling();
    _connectionStateController.close();
    _isScanningController.close();
    _timingDataController.close();
    _statusController.close();
    _deviceStatusController.close();
    _heartbeatController.close();
    _hitCountController.close();
    _lastValueSubscription?.cancel();
  }
}
