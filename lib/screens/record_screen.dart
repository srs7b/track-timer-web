import 'dart:async';
import 'dart:js' as js; // For "Nuclear" JS diagnostics
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import '../services/ble_service.dart';
import '../theme/style_constants.dart';
import '../widgets/velocity_card.dart';
import '../widgets/velocity_button.dart';
import '../widgets/status_indicator.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final DatabaseService _db = DatabaseService();
  final BleService _bleService = BleService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<User> _users = [];
  User? _selectedUser;
  int _selectedDistance = 100;
  String _selectedSurface = 'Synthetic Track (Outdoor)';

  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  BleDeviceStatus _deviceStatus = BleDeviceStatus.disconnected;
  String _statusMsg = "READY";
  DateTime? _lastHeartbeat;
  bool _heartbeatPulse = false;
  int _hitCount = 0;

  bool _isCountingDown = false;
  int _countdownValue = 3;

  StreamSubscription? _connectionSub;

  List<double> _nodeDistances = [50.0, 50.0];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _setupBleListeners();
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _bleService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupBleListeners() {
    _connectionSub = _bleService.connectionState.listen((state) {
      if (mounted) {
        setState(() => _connectionState = state);
        if (state == BluetoothConnectionState.disconnected && _isCountingDown) {
          setState(() => _isCountingDown = false);
        }
      }
    });

    _bleService.timingDataStream.listen((offsets) {
      if (mounted) _handleFinalTiming(offsets);
    });

    _bleService.statusMessage.listen((msg) {
      if (mounted) setState(() => _statusMsg = msg);
    });

    _bleService.deviceStatus.listen((status) {
      if (mounted) {
        setState(() => _deviceStatus = status);
        if (status == BleDeviceStatus.disconnected && _isCountingDown) {
          setState(() => _isCountingDown = false);
        }
      }
    });

    _bleService.heartbeatStream.listen((time) {
      if (mounted) {
        setState(() {
          _lastHeartbeat = time;
          _heartbeatPulse = true;
        });
        // Briefly show the pulse
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _heartbeatPulse = false);
        });
      }
    });

    _bleService.hitCount.listen((count) {
      if (mounted) setState(() => _hitCount = count);
    });
  }

  Future<void> _startCountdownSequence() async {
    if (_isCountingDown) return;
    
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
    });

    for (int i = 3; i >= 1; i--) {
      if (!_isCountingDown) return; 
      
      setState(() => _countdownValue = i);
      try {
        await _playAssetSafe('audio/beep.mp3');
      } catch (e) {
        debugPrint("Audio Error: $e");
        if (mounted) setState(() => _statusMsg = "AUDIO ERROR: $e");
      }
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!_isCountingDown) return;
    
    // 1. Show "GO!" instantly
    setState(() => _countdownValue = 0);

    // 2. Fire audio shot immediately (non-blocking)
    _playAssetSafe('audio/race_start.wav').catchError((e) {
      debugPrint("Shot Audio Error: $e");
    });
    
    // 3. Trigger BLE Start command immediately (non-blocking)
    _bleService.sendStartCommand().catchError((e) {
      debugPrint("BLE Start command failed: $e");
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('START TRIGGERED'), duration: Duration(milliseconds: 800)),
      );
    }

    // 4. Keep "GO!" overlay visible for a fixed duration, then close
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _isCountingDown = false);
    }
  }

  /// Robust audio player that handles Web path discrepancies
  Future<void> _playAssetSafe(String path) async {
    try {
      // Strategy 1: Standard AssetSource (relative to assets/)
      await _audioPlayer.play(AssetSource(path));
    } catch (e) {
      if (kIsWeb) {
        debugPrint("Primary Audio Load Failed, trying strategy 2: $e");
        try {
          // Strategy 2: Explicit assets/ prefix (double assets in build)
          await _audioPlayer.play(AssetSource('assets/$path'));
        } catch (e2) {
          debugPrint("Secondary Audio Load Failed: $e2");
          throw e2;
        }
      } else {
        rethrow;
      }
    }
  }

  void _showSystemHealthDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VelocityColors.surface,
        title: Text("SYSTEM HEALTH", style: VelocityTextStyles.subHeading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHealthItem("Platform", kIsWeb ? "Web (Chrome)" : "Native"),
            if (kIsWeb) _buildHealthItem("Base Href", Uri.base.path),
            if (kIsWeb) _buildHealthItem("Full Location", Uri.base.toString()),
            _buildHealthItem("Device Status", _deviceStatus.toString()),
            const Divider(color: Colors.white10),
            Text("AUDIO PATH TESTS", style: VelocityTextStyles.technical.copyWith(fontSize: 12, color: VelocityColors.primary)),
            const SizedBox(height: 8),
            _buildPathTestButton("Strategy 1 (audio/beep.mp3)", "AssetSource", "audio/beep.mp3"),
            _buildPathTestButton("Strategy 2 (assets/audio/beep.mp3)", "AssetSource", "assets/audio/beep.mp3"),
            _buildPathTestButton("Strategy 3 (assets/assets/audio/beep.mp3)", "AssetSource", "assets/assets/audio/beep.mp3"),
            const SizedBox(height: 8),
            Text("WAV TESTS (More reliable on Web)", style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: Colors.orangeAccent)),
            _buildPathTestButton("WAV (audio/race_start.wav)", "AssetSource", "audio/race_start.wav"),
            _buildPathTestButton("WAV (assets/audio/race_start.wav)", "AssetSource", "assets/audio/race_start.wav"),
            _buildPathTestButton("WAV (assets/assets/audio/race_start.wav)", "AssetSource", "assets/assets/audio/race_start.wav"),
            const SizedBox(height: 8),
            Text("NUCLEAR WEB TESTS", style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: Colors.redAccent)),
            _buildPathTestButton("UrlSource (Relative)", "UrlSource", "assets/audio/race_start.wav"),
            _buildPathTestButton("UrlSource (Nested)", "UrlSource", "assets/assets/audio/race_start.wav"),
            _buildPathTestButton("Nuclear JS Test", "JSSource", "assets/assets/audio/race_start.wav"),
            const SizedBox(height: 12),
            Text("Note: Strategy 3 or Nested UrlSource is often required for GitHub Pages deployments.", 
                 style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: VelocityColors.textDim)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CLOSE", style: VelocityTextStyles.body.copyWith(color: VelocityColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label: ", style: VelocityTextStyles. technical.copyWith(color: VelocityColors.textDim, fontSize: 11)),
          Text(value, style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textBody, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildPathTestButton(String label, String type, String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: VelocityColors.surfaceLight),
          onPressed: () async {
            try {
              if (type == "AssetSource") {
                await _audioPlayer.play(AssetSource(path));
              } else if (type == "UrlSource") {
                // Resolve relative to the current location
                final resolved = Uri.base.resolve(path).toString();
                debugPrint("Testing UrlSource: $resolved");
                await _audioPlayer.play(UrlSource(resolved));
              } else if (type == "JSSource") {
                if (kIsWeb) {
                  // Direct HTML5 Audio Test via JS
                  final resolved = Uri.base.resolve(path).toString();
                  js.context.callMethod('eval', [
                    "new Audio('$resolved').play();"
                  ]);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("JS AUDIO INVOKED (Check console)")));
                  return;
                }
              }
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PLAYBACK SUCCESS: $path")));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("FAILED: $e"), backgroundColor: Colors.red));
              }
            }
          },
          child: Text(label, style: VelocityTextStyles.technical.copyWith(fontSize: 10)),
        ),
      ),
    );
  }

  void _handleFinalTiming(List<int> offsets) {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DATA RECEIVED BUT NO ATHLETE SELECTED')));
      return;
    }

    final newRun = Run(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: _selectedUser!.id,
      name: '${_selectedUser!.name.split(' ').first} ${_selectedDistance}M',
      timestamp: DateTime.now(),
      nodeDistances: _nodeDistances,
      gateTimeOffsets: offsets,
      distanceClass: _selectedDistance,
      notes: 'Recorded via BLE Demo ($_selectedSurface)',
    );

    _showResultDialog(newRun);
  }

  Future<void> _showResultDialog(Run initialRun) async {
    List<int> currentOffsets = List.from(initialRun.gateTimeOffsets);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Recalculate summary metrics based on trimmed list
          double totalTime = 0.0;
          if (currentOffsets.length >= 2) {
            totalTime = (currentOffsets.last - currentOffsets.first) / 1000.0;
          }

          return AlertDialog(
            backgroundColor: VelocityColors.surfaceLight,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SESSION CAPTURED', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary, fontSize: 13)),
                Text('${currentOffsets.length} GATES', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textDim, fontSize: 10)),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxHeight: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ATHLETE: ${initialRun.name.split(' ').first}', style: VelocityTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                          Text('SURFACE: $_selectedSurface', style: VelocityTextStyles.dimBody.copyWith(fontSize: 9)),
                        ],
                      ),
                      Text(
                        '${totalTime.toStringAsFixed(2)}s', 
                        style: VelocityTextStyles.heading.copyWith(fontSize: 32, color: VelocityColors.primary)
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('TRIM GATES (TAP TO REMOVE)', style: VelocityTextStyles.dimBody.copyWith(fontSize: 9, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: VelocityColors.textDim.withValues(alpha: 0.1)),
                      ),
                      child: currentOffsets.isEmpty 
                        ? Center(child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text('NO GATES RECORDED', style: VelocityTextStyles.dimBody),
                          ))
                        : ListView.separated(
                          shrinkWrap: true,
                          itemCount: currentOffsets.length,
                          separatorBuilder: (context, index) => Divider(height: 1, color: VelocityColors.textDim.withValues(alpha: 0.05)),
                          itemBuilder: (context, index) {
                            int offset = currentOffsets[index];
                            double relativeTime = (index == 0) ? 0.0 : (offset - currentOffsets[0]) / 1000.0;
                            
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text('GATE ${index + 1}', style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: VelocityColors.textBody)),
                              subtitle: Text('${relativeTime.toStringAsFixed(3)}s', style: VelocityTextStyles.body.copyWith(fontSize: 14)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                onPressed: () {
                                  setDialogState(() {
                                    currentOffsets.removeAt(index);
                                  });
                                },
                              ),
                            );
                          },
                        ),
                    ),
                  ),
                  if (currentOffsets.length < 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text('⚠️ NEED AT LEAST 2 GATES TO CALCULATE TIME', style: VelocityTextStyles.technical.copyWith(color: Colors.orangeAccent, fontSize: 9)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('DISCARD', style: VelocityTextStyles.technical.copyWith(color: Colors.redAccent)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VelocityColors.primary,
                  disabledBackgroundColor: VelocityColors.textDim.withValues(alpha: 0.2),
                ),
                onPressed: currentOffsets.length >= 2 ? () async {
                  final trimmedRun = Run(
                    id: initialRun.id,
                    userId: initialRun.userId,
                    name: initialRun.name,
                    timestamp: initialRun.timestamp,
                    nodeDistances: initialRun.nodeDistances,
                    gateTimeOffsets: currentOffsets,
                    distanceClass: initialRun.distanceClass,
                    notes: initialRun.notes,
                  );
                  
                  await _db.saveRun(trimmedRun);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SESSION SAVED TO LOG')),
                    );
                  }
                } : null,
                child: Text('KEEP RECORD', style: VelocityTextStyles.technical.copyWith(color: Colors.black)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editNodeDistances() async {
    List<TextEditingController> controllers = _nodeDistances
        .map((d) => TextEditingController(text: d.toStringAsFixed(1)))
        .toList();

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: VelocityColors.surfaceLight,
          title: Text('CONFIGURE GATE SEGMENTS', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary, fontSize: 13)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(controllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextField(
                    controller: controllers[i],
                    style: VelocityTextStyles.body,
                    decoration: InputDecoration(
                      labelText: 'SEGMENT ${i + 1} DISTANCE (m)',
                      labelStyle: VelocityTextStyles.dimBody,
                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: VelocityColors.textDim)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: VelocityColors.primary)),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCEL', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textDim)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('UPDATE', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary)),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      setState(() {
        _nodeDistances = controllers.map((c) => double.tryParse(c.text) ?? 0.0).toList();
      });
    }
  }

  Future<void> _loadUsers() async {
    final users = await _db.getAllUsers();
    if (mounted) {
      setState(() {
        _users = users;
        if (_users.isNotEmpty && _selectedUser == null) {
          _selectedUser = _users.first;
        }
      });
    }
  }

  Future<void> _showBleScanDialog() async {
    _bleService.startScan();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VelocityColors.surfaceLight,
        title: Text('SCANNING FOR HARDWARE', style: VelocityTextStyles.technical.copyWith(fontSize: 14, color: VelocityColors.primary)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<List<ScanResult>>(
            stream: _bleService.scanResults,
            builder: (context, snapshot) {
              final results = snapshot.data ?? [];
              if (results.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: VelocityColors.primary));
              }
              return ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final r = results[index];
                  final name = r.device.platformName.isNotEmpty ? r.device.platformName : 'Unknown Node';
                  return ListTile(
                    title: Text(name, style: VelocityTextStyles.body),
                    subtitle: Text(r.device.remoteId.toString(), style: VelocityTextStyles.dimBody.copyWith(fontSize: 10)),
                    trailing: const Icon(Icons.link, color: VelocityColors.primary),
                    onTap: () async {
                      _bleService.stopScan();
                      Navigator.pop(context);
                      
                      // Sequential LightBlue-style handshake
                      try {
                        await _bleService.connectToDevice(r.device);
                        // Brief pause between connect and discover
                        await _bleService.prepareHardware();
                      } catch (e) {
                        debugPrint("Handshake failed: $e");
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _bleService.stopScan();
              Navigator.pop(context);
            },
            child: Text('CANCEL', style: VelocityTextStyles.technical.copyWith(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showDistancePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: VelocityColors.surfaceLight,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CHOOSE TEST DISTANCE', style: VelocityTextStyles.dimBody.copyWith(fontSize: 12, letterSpacing: 2)),
            const SizedBox(height: 16),
            ...[100, 200, 400].map((d) => ListTile(
              title: Center(child: Text('${d}M SPRINT', style: VelocityTextStyles.heading.copyWith(fontSize: 18, color: _selectedDistance == d ? VelocityColors.primary : VelocityColors.textBody))),
              onTap: () {
                setState(() => _selectedDistance = d);
                Navigator.pop(context);
              },
            )),
            ListTile(
              title: Center(child: Text('OTHER (MANUAL)', style: VelocityTextStyles.heading.copyWith(fontSize: 18, color: _selectedDistance > 400 || (_selectedDistance != 100 && _selectedDistance != 200 && _selectedDistance != 400) ? VelocityColors.primary : VelocityColors.textBody))),
              onTap: () {
                Navigator.pop(context);
                _showCustomDistanceDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomDistanceDialog() async {
    final controller = TextEditingController(text: _selectedDistance.toString());
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VelocityColors.surfaceLight,
        title: Text('SET CUSTOM DISTANCE (M)', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary)),
        content: TextField(
          controller: controller,
          style: VelocityTextStyles.body,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'TOTAL DISTANCE',
            labelStyle: VelocityTextStyles.dimBody,
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: VelocityColors.textDim)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: VelocityColors.primary)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textDim))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('SET', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary))),
        ],
      ),
    );

    if (saved == true) {
      int? dist = int.tryParse(controller.text);
      if (dist != null) {
        setState(() => _selectedDistance = dist);
      }
    }
  }

  void _showSurfacePicker() {
    final surfaces = ['Synthetic Track (Outdoor)', 'Natural Grass', 'Indoor Track', 'Sand / Beach'];
    showModalBottomSheet(
      context: context,
      backgroundColor: VelocityColors.surfaceLight,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CHOOSE SURFACE TYPE', style: VelocityTextStyles.dimBody.copyWith(fontSize: 12, letterSpacing: 2)),
            const SizedBox(height: 16),
            ...surfaces.map((s) => ListTile(
              title: Center(child: Text(s.toUpperCase(), style: VelocityTextStyles.body.copyWith(color: _selectedSurface == s ? VelocityColors.primary : VelocityColors.textBody))),
              onTap: () {
                setState(() => _selectedSurface = s);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = _connectionState == BluetoothConnectionState.connected;

    return Scaffold(
      backgroundColor: VelocityColors.black,
      appBar: AppBar(
        title: Text('TRACK.TIME', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textBody, letterSpacing: 4)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
            // Status Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: VelocityCard(
                      borderColor: isConnected ? VelocityColors.primary.withValues(alpha: 0.3) : null,
                      glow: isConnected,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.bluetooth, color: isConnected ? VelocityColors.primary : VelocityColors.textDim, size: 20),
                          const SizedBox(height: 12),
                          StatusIndicator(
                            label: 'BLE HARDWARE',
                            value: _deviceStatus == BleDeviceStatus.ready 
                              ? (_bleService.connectedDevice?.platformName ?? 'TRACKNODE_01') 
                              : _deviceStatus.name.toUpperCase(),
                            active: _deviceStatus == BleDeviceStatus.ready,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                   Expanded(
                    child: InkWell(
                      onTap: isConnected ? () => _bleService.disconnect() : null,
                      child: VelocityCard(
                        borderColor: isConnected ? Colors.redAccent.withValues(alpha: 0.3) : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.stop_circle, color: isConnected ? Colors.redAccent : VelocityColors.textDim, size: 20),
                            const SizedBox(height: 12),
                            StatusIndicator(
                              label: 'ACTIVE SESSION',
                              value: _hitCount > 0 ? '$_hitCount GATES CROSSED' : (isConnected ? 'READY TO STOP' : 'OFFLINE'),
                              active: _hitCount > 0, // Glow when data is coming in
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Configuration Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: VelocityColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VelocityColors.textDim.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONFIGURATION', style: VelocityTextStyles.dimBody.copyWith(fontSize: 10, letterSpacing: 2)),
                    const SizedBox(height: 24),
                    
                    _buildConfigLabel('ATHLETE SELECTION'),
                    const SizedBox(height: 12),
                    _buildDropdown<User>(
                      value: _selectedUser,
                      items: _users.map((u) => DropdownMenuItem(value: u, child: Text(u.name))).toList(),
                      hint: 'Select Athlete',
                      onChanged: (val) => setState(() => _selectedUser = val),
                    ),
                    
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildConfigLabel('TEST DISTANCE'),
                              const SizedBox(height: 12),
                              _buildPillSelector('${_selectedDistance}m', onTap: _showDistancePicker),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildConfigLabel('SEGMENT CONFIG'),
                              const SizedBox(height: 12),
                              _buildPillSelector('${_nodeDistances.length} GATES', icon: Icons.straighten, onTap: _editNodeDistances),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _buildConfigLabel('SURFACE TYPE'),
                    const SizedBox(height: 12),
                    _buildPillSelector(_selectedSurface, icon: Icons.expand_more, onTap: _showSurfacePicker),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Primary Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VelocityButton(
                label: _isCountingDown 
                  ? 'GET READY...' 
                  : (_deviceStatus == BleDeviceStatus.ready ? 'START SESSION' : 'HARDWARE NOT READY'),
                onPressed: (_deviceStatus == BleDeviceStatus.ready && !_isCountingDown) 
                  ? _startCountdownSequence 
                  : null,
                icon: _isCountingDown ? Icons.timer : Icons.play_arrow,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Secondary Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: VelocityButton(
                      label: 'SCAN FOR HARDWARE',
                      primary: false,
                      icon: Icons.search,
                      onPressed: _showBleScanDialog,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Diagnostic Panel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VelocityColors.textDim.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _statusMsg.contains("ERROR") 
                          ? Colors.red 
                          : (_deviceStatus == BleDeviceStatus.ready ? (_heartbeatPulse ? VelocityColors.primary : Colors.green) : Colors.blue),
                        shape: BoxShape.circle,
                        boxShadow: _heartbeatPulse ? [
                          BoxShadow(color: VelocityColors.primary.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)
                        ] : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "DIAGNOSTIC LOG: $_statusMsg",
                                  style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: VelocityColors.textDim),
                                  softWrap: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_deviceStatus != BleDeviceStatus.disconnected)
                                InkWell(
                                  onTap: () => _bleService.readData(),
                                  child: Text(
                                    "[FORCE READ]",
                                    style: VelocityTextStyles.technical.copyWith(
                                      fontSize: 9, 
                                      color: VelocityColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              InkWell(
                                onTap: _startCountdownSequence,
                                child: Text(
                                  "[TEST AUDIO]",
                                  style: VelocityTextStyles.technical.copyWith(
                                    fontSize: 9, 
                                    color: Colors.orangeAccent,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              InkWell(
                                onTap: _showSystemHealthDialog,
                                child: Text(
                                  "[HEALTH]",
                                  style: VelocityTextStyles.technical.copyWith(
                                    fontSize: 9, 
                                    color: Colors.cyanAccent,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_lastHeartbeat != null)
                            Text(
                              "LAST LIVE PING: ${_lastHeartbeat!.hour}:${_lastHeartbeat!.minute.toString().padLeft(2, '0')}:${_lastHeartbeat!.second.toString().padLeft(2, '0')}",
                              style: VelocityTextStyles.technical.copyWith(fontSize: 8, color: VelocityColors.primary.withValues(alpha: 0.5)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
      if (_isCountingDown)
        Container(
          color: Colors.black.withValues(alpha: 0.8),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: Text(
                    _countdownValue == 0 ? 'GO!' : '$_countdownValue',
                    key: ValueKey(_countdownValue),
                    style: VelocityTextStyles.heading.copyWith(
                      fontSize: 120,
                      color: _countdownValue == 0 ? VelocityColors.primary : Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'GET STEADY',
                  style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textDim, letterSpacing: 4),
                ),
              ],
            ),
          ),
        ),
    ],
  ),
);
  }

  Widget _buildConfigLabel(String label) {
    return Text(
      label,
      style: VelocityTextStyles.dimBody.copyWith(fontSize: 9, letterSpacing: 1),
    );
  }

  Widget _buildPillSelector(String value, {IconData? icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: VelocityColors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VelocityColors.textDim.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(value, style: VelocityTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
            Icon(icon ?? Icons.edit, size: 14, color: VelocityColors.textDim),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({T? value, required List<DropdownMenuItem<T>> items, required String hint, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VelocityColors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VelocityColors.textDim.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          hint: Text(hint, style: VelocityTextStyles.dimBody),
          onChanged: onChanged,
          dropdownColor: VelocityColors.surfaceLight,
          isExpanded: true,
          icon: const Icon(Icons.group, size: 16, color: VelocityColors.textDim),
        ),
      ),
    );
  }

}
