import 'dart:async';
import 'package:flutter/material.dart';
import '../models/run_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/mock_data_service.dart';
import '../services/data_processing_service.dart';
import 'package:intl/intl.dart';
import 'run_details_screen.dart';

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

  List<User> _users = [];
  Map<String, User> _userMap = {};

  // Filters
  String _filterGender = 'All'; // 'All', 'M', 'F'
  String? _filterAthleteId;
  int? _filterDistance; // null = All, 100, 200, 400
  DateTimeRange? _filterDateRange;

  late StreamSubscription<void> _dbSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _dbSub = DatabaseService.onChange.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _dbSub.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final runs = await _db.getAllRuns();
      final users = await _db.getAllUsers();
      Map<String, User> uMap = {for (var u in users) u.id: u};

      setState(() {
        _runs = runs;
        _users = users;
        _userMap = uMap;
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

  Future<void> _generateMockRun() async {
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
      name: 'Unassigned Mock Run ${_runs.length + 1}',
      timestamp: DateTime.now(),
      nodeDistances: distances,
      voltageData: voltageData,
      gateTimeOffsets: gateOffsets,
      userId: null,
      distanceClass: 100,
      notes: 'Auto-generated mock run',
    );

    await _db.saveRun(newRun);
    _loadData();
  }

  Future<void> _deleteRun(String id) async {
    await _db.deleteRun(id);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Timer')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_fab',
        onPressed: _generateMockRun,
        icon: const Icon(Icons.add),
        label: const Text('Generate Mock Run'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error: $_errorMessage',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    // Apply filters
    List<Run> filteredRuns = _runs.where((run) {
      if (_filterAthleteId != null && run.userId != _filterAthleteId) {
        return false;
      }
      if (_filterDistance != null && run.distanceClass != _filterDistance) {
        return false;
      }
      if (_filterDateRange != null) {
        if (run.timestamp.isBefore(_filterDateRange!.start) ||
            run.timestamp.isAfter(
              _filterDateRange!.end.add(const Duration(days: 1)),
            )) {
          return false;
        }
      }
      if (_filterGender != 'All') {
        final user = _userMap[run.userId];
        if (user == null || user.gender != _filterGender) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: filteredRuns.isEmpty
              ? const Center(child: Text('No runs match criteria.'))
              : ListView.builder(
                  itemCount: filteredRuns.length,
                  itemBuilder: (context, index) {
                    final run = filteredRuns[index];
                    final dateStr = DateFormat.yMMMd().add_jm().format(
                      run.timestamp,
                    );
                    final userName =
                        run.userId != null && _userMap.containsKey(run.userId)
                        ? _userMap[run.userId]!.name
                        : 'Unassigned';
                    final gender =
                        run.userId != null && _userMap.containsKey(run.userId)
                        ? _userMap[run.userId]!.gender
                        : '?';

                    return ListTile(
                      title: Text(run.name),
                      subtitle: Text(
                        '$userName ($gender) • ${run.distanceClass}m • ${run.totalTimeSeconds.toStringAsFixed(2)}s\n$dateStr',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.blueGrey),
                        onPressed: () => _deleteRun(run.id),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RunDetailsScreen(run: run),
                          ),
                        ).then((_) => _loadData());
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      width: double.infinity,
      color: Theme.of(context).cardColor,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12.0,
        runSpacing: 8.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Gender Filter
          DropdownButton<String>(
            value: _filterGender,
            hint: const Text('Gender'),
            items: [
              'All',
              'M',
              'F',
              'Unknown',
            ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (val) => setState(() => _filterGender = val ?? 'All'),
          ),
          const SizedBox(width: 12),
          // Athlete Filter
          DropdownButton<String?>(
            value: _filterAthleteId,
            hint: const Text('Athlete'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Athletes'),
              ),
              ..._users.map(
                (u) => DropdownMenuItem(value: u.id, child: Text(u.name)),
              ),
            ],
            onChanged: (val) => setState(() => _filterAthleteId = val),
          ),
          const SizedBox(width: 12),
          // Distance Filter
          DropdownButton<int?>(
            value: _filterDistance,
            hint: const Text('Distance'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All Distances'),
              ),
              const DropdownMenuItem<int?>(value: 100, child: Text('100m')),
              const DropdownMenuItem<int?>(value: 200, child: Text('200m')),
              const DropdownMenuItem<int?>(value: 400, child: Text('400m')),
            ],
            onChanged: (val) => setState(() => _filterDistance = val),
          ),
          const SizedBox(width: 12),
          // Date Filter
          ActionChip(
            label: Text(
              _filterDateRange == null
                  ? 'Date Range'
                  : '${DateFormat.MMMd().format(_filterDateRange!.start)} - ${DateFormat.MMMd().format(_filterDateRange!.end)}',
            ),
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _filterDateRange,
              );
              if (range != null) {
                setState(() => _filterDateRange = range);
              }
            },
          ),
          if (_filterGender != 'All' ||
              _filterAthleteId != null ||
              _filterDistance != null ||
              _filterDateRange != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                setState(() {
                  _filterGender = 'All';
                  _filterAthleteId = null;
                  _filterDistance = null;
                  _filterDateRange = null;
                });
              },
              tooltip: 'Clear Filters',
            ),
          ],
        ],
      ),
    );
  }
}
