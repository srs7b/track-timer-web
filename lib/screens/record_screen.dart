import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
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
  List<User> _users = [];
  User? _selectedUser;
  int _selectedDistance = 100;
  String _selectedSurface = 'Synthetic Track (Outdoor)';

  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  bool _isWifiOn = false;

  StreamSubscription? _connectionSub;

  List<double> _nodeDistances = [10.0, 20.0, 30.0, 40.0];

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
    super.dispose();
  }

  void _setupBleListeners() {
    _connectionSub = _bleService.connectionState.listen((state) {
      if (mounted) setState(() => _connectionState = state);
    });
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
                    onTap: () {
                      _bleService.stopScan();
                      _bleService.connectToDevice(r.device);
                      Navigator.pop(context);
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
          ],
        ),
      ),
    );
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
      body: SingleChildScrollView(
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
                      borderColor: isConnected ? VelocityColors.primary.withOpacity(0.3) : null,
                      glow: isConnected,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.bluetooth, color: isConnected ? VelocityColors.primary : VelocityColors.textDim, size: 20),
                          const SizedBox(height: 12),
                          StatusIndicator(
                            label: 'BLE HARDWARE',
                            value: isConnected ? (_bleService.connectedDevice?.platformName ?? 'CHRONO-GATE_01') : 'DISCONNECTED',
                            active: isConnected,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                   Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isWifiOn = !_isWifiOn),
                      child: VelocityCard(
                        borderColor: _isWifiOn ? VelocityColors.primary.withOpacity(0.3) : null,
                        glow: _isWifiOn,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.wifi_tethering, color: _isWifiOn ? VelocityColors.primary : VelocityColors.textDim, size: 20),
                            const SizedBox(height: 12),
                            StatusIndicator(
                              label: 'WIFI SYNC',
                              value: _isWifiOn ? 'CONNECTED' : 'STANDBY',
                              active: _isWifiOn,
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
                  border: Border.all(color: VelocityColors.textDim.withOpacity(0.05)),
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
                label: isConnected ? 'START SESSION' : 'HARDWARE OFFLINE',
                onPressed: isConnected ? () {} : null,
                icon: Icons.play_arrow,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Secondary Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: VelocityButton(
                  label: 'SCAN FOR HARDWARE',
                  primary: false,
                  icon: Icons.search,
                  onPressed: _showBleScanDialog,
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
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
          border: Border.all(color: VelocityColors.textDim.withOpacity(0.2)),
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
        border: Border.all(color: VelocityColors.textDim.withOpacity(0.2)),
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
