import 'package:flutter/material.dart';
import '../models/run_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/mock_data_service.dart';
import '../services/data_processing_service.dart';
import 'package:intl/intl.dart';
import 'run_details_screen.dart';
import 'overlay_screen.dart';
import 'users_list_screen.dart';
import 'general_statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  List<Run> _runs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRuns();
  }

  Future<void> _loadRuns() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final runs = await _db.getAllRuns();
      setState(() {
        _runs = runs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading runs: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<User?> _showUserSelectionDialog() async {
    final users = await _db.getAllUsers();
    User? selectedUser;

    return showDialog<User>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Athlete'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (users.isEmpty)
                      const Text('No athletes found. Please create one.')
                    else
                      DropdownButton<User>(
                        isExpanded: true,
                        hint: const Text('Select existing athlete'),
                        value: selectedUser,
                        items: users
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Text(u.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedUser = val);
                        },
                      ),
                    const Divider(),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create New Athlete'),
                      onPressed: () async {
                        final newName = await _showCreateUserDialog();
                        if (newName != null && newName.isNotEmpty) {
                          final newUser = User(
                            id: DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            name: newName,
                            createdDate: DateTime.now(),
                          );
                          await _db.saveUser(newUser);

                          if (mounted) {
                            Navigator.pop(
                              context,
                              newUser,
                            ); // Return new user immediately
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedUser != null
                      ? () => Navigator.pop(context, selectedUser)
                      : null,
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showCreateUserDialog() {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Athlete'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateMockRun() async {
    final User? selectedUser = await _showUserSelectionDialog();
    if (selectedUser == null) return; // Cancelled mock generation

    // Generate a run simulating a ~10s 100m dash +/- 1.5 seconds
    int mockDurationMs =
        9000 +
        (DateTime.now().millisecond * 3); // Randomish between 9.0s and ~12.0s
    List<double> distances = [25.0, 25.0, 25.0, 25.0];

    final mockResult = MockDataService.generateMockRunData(
      durationMs: mockDurationMs,
    );
    final voltageData = mockResult['voltageData'] as List<double>;
    final sampleRate = mockResult['sampleRateHz'] as int;

    // Process data to find gate times
    List<int> gateOffsets = DataProcessingService.detectPeaks(
      voltageData,
      sampleRateHz: sampleRate,
    );

    final newRun = Run(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${selectedUser.name} - Mock Run ${_runs.length + 1}',
      timestamp: DateTime.now(),
      nodeDistances: distances,
      voltageData: voltageData,
      gateTimeOffsets: gateOffsets,
      userId: selectedUser.id,
      notes: 'Auto-generated mock run',
    );

    await _db.saveRun(newRun);
    _loadRuns();
  }

  Future<void> _deleteRun(String id) async {
    await _db.deleteRun(id);
    _loadRuns();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Global Stats',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GeneralStatisticsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Athletes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UsersListScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Overlay Runs',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OverlayScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            )
          : _runs.isEmpty
          ? const Center(
              child: Text('No runs recorded yet. Generate a mock run!'),
            )
          : ListView.builder(
              itemCount: _runs.length,
              itemBuilder: (context, index) {
                final run = _runs[index];
                final dateStr = DateFormat.yMMMd().add_jm().format(
                  run.timestamp,
                );
                return ListTile(
                  title: Text(run.name),
                  subtitle: Text(
                    '${run.totalEventDistance.toStringAsFixed(1)}m • ${run.totalTimeSeconds.toStringAsFixed(2)}s • $dateStr',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _deleteRun(run.id),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RunDetailsScreen(run: run),
                      ),
                    ).then((_) => _loadRuns());
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateMockRun,
        icon: const Icon(Icons.add),
        label: const Text('Generate Mock Run'),
      ),
    );
  }
}
