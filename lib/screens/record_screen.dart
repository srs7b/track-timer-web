import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import '../services/mock_data_service.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final DatabaseService _db = DatabaseService();
  List<User> _users = [];
  User? _selectedUser;
  int _selectedDistance = 100;

  bool _isBleScanning = false;
  bool _isBleConnected = false;
  bool _isWifiOn = false;

  final TextEditingController _nodesController = TextEditingController(
    text: "25.0, 25.0, 25.0, 25.0",
  );

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await _db.getAllUsers();
    setState(() {
      _users = users;
    });
  }

  void _toggleBleScan() {
    setState(() {
      _isBleScanning = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isBleScanning = false;
          _isBleConnected = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Simulated BLE Connection Successful')),
        );
      }
    });
  }

  void _toggleWifi() {
    setState(() {
      _isWifiOn = !_isWifiOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Run')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              elevation: 4,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Icon(
                          Icons.bluetooth,
                          size: 40,
                          color: _isBleConnected ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isBleConnected
                              ? 'BLE Connected'
                              : 'BLE Disconnected',
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(
                          Icons.wifi_tethering,
                          size: 40,
                          color: _isWifiOn ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(_isWifiOn ? 'System Ready' : 'System Off'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Connection Controls
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBleScanning ? null : _toggleBleScan,
                    icon: _isBleScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(_isBleConnected ? 'Rescan BLE' : 'Scan BLE'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isWifiOn ? Colors.green.shade700 : null,
                      foregroundColor: _isWifiOn ? Colors.white : null,
                    ),
                    onPressed: _toggleWifi,
                    icon: Icon(
                      _isWifiOn ? Icons.power_settings_new : Icons.power,
                    ),
                    label: Text(_isWifiOn ? 'Power Off' : 'Power On'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Run Configuration
            Text(
              'Run Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<User>(
              decoration: const InputDecoration(
                labelText: 'Athlete',
                border: OutlineInputBorder(),
              ),
              items: _users
                  .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
                  .toList(),
              initialValue: _selectedUser,
              onChanged: (val) => setState(() => _selectedUser = val),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Distance Class',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedDistance,
                    items: const [
                      DropdownMenuItem(value: 100, child: Text('100m')),
                      DropdownMenuItem(value: 200, child: Text('200m')),
                      DropdownMenuItem(value: 400, child: Text('400m')),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedDistance = val ?? 100),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nodesController,
                    decoration: const InputDecoration(
                      labelText: 'Node Distances (csv)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              onPressed: (_isBleConnected && _isWifiOn && _selectedUser != null)
                  ? () async {
                      List<double> distances = [];
                      try {
                        distances = _nodesController.text
                            .split(',')
                            .map((e) => double.parse(e.trim()))
                            .toList();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid node distances CSV.'),
                          ),
                        );
                        return;
                      }

                      double totalDistance = distances.fold(
                        0.0,
                        (sum, d) => sum + d,
                      );
                      if ((totalDistance - _selectedDistance).abs() > 10.0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Warning: Node distances sum to ${totalDistance}m, mismatching the ${_selectedDistance}m class!',
                            ),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Recording mock run for ${_selectedUser!.name}...',
                          ),
                        ),
                      );

                      await Future.delayed(const Duration(seconds: 1));

                      final mockData = MockDataService.generateMockRunData(
                        durationMs: 10500,
                      );
                      List<int> allOffsets =
                          mockData['trueGateOffsets'] as List<int>;
                      List<int> gateOffsets = allOffsets
                          .take(distances.length + 1)
                          .toList();

                      final newRun = Run(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: 'Recorded Run (${_selectedDistance}m)',
                        timestamp: DateTime.now(),
                        nodeDistances: distances,
                        voltageData: mockData['voltageData'] as List<double>,
                        gateTimeOffsets: gateOffsets.isNotEmpty
                            ? gateOffsets
                            : [0, 2000],
                        userId: _selectedUser!.id,
                        distanceClass: _selectedDistance,
                        notes: 'Generated via Record Tab',
                      );

                      await DatabaseService().saveRun(newRun);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Run recorded successfully!'),
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text(
                'Start Recording',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
