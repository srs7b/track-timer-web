import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/run_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class _ComparisonSeries {
  final String label;
  final Color color;
  final List<FlSpot> positionSpots;
  final List<FlSpot> velocitySpots;
  final List<FlSpot> accelerationSpots;
  final double maxTime;

  _ComparisonSeries({
    required this.label,
    required this.color,
    required this.positionSpots,
    required this.velocitySpots,
    required this.accelerationSpots,
    required this.maxTime,
  });
}

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  final DatabaseService _db = DatabaseService();
  final PageController _pageController = PageController();

  List<Run> _allRuns = [];
  List<User> _allUsers = [];
  bool _isLoading = true;

  final List<_ComparisonSeries> _seriesList = [];

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];
  int _colorIndex = 0;
  late StreamSubscription<void> _dbSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _dbSub = DatabaseService.onChange.listen((_) {
      if (mounted) {
        _seriesList
            .clear(); // Clear graph automatically on db refresh for simplicity
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _dbSub.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final runs = await _db.getAllRuns();
    final users = await _db.getAllUsers();
    setState(() {
      _allRuns = runs;
      _allUsers = users;
      _isLoading = false;
    });
  }

  Color _getNextColor() {
    Color c = _availableColors[_colorIndex % _availableColors.length];
    _colorIndex++;
    return c;
  }

  void _removeSeries(int index) {
    setState(() {
      _seriesList.removeAt(index);
    });
  }

  Future<void> _showAddDialog() async {
    if (_allUsers.isEmpty || _allRuns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No athletes or runs available to compare.'),
        ),
      );
      return;
    }

    User? selectedUser;
    int? selectedDistance;
    String? selectedMetric; // 'Average', 'PB', 'L5', 'L10', 'Specific'
    String? averageTimeframe =
        'All Time'; // 'All Time', 'Today', 'Week', 'Month'
    Run? selectedSpecificRun;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filter distance options based on user's runs
            List<int> availableDistances = [];
            if (selectedUser != null) {
              final userRuns = _allRuns.where(
                (r) => r.userId == selectedUser!.id,
              );
              availableDistances = userRuns
                  .map((r) => r.distanceClass)
                  .toSet()
                  .toList();
              availableDistances.sort();
            }

            // Filter specific runs if metric is 'Specific'
            List<Run> specificRuns = [];
            if (selectedUser != null &&
                selectedDistance != null &&
                selectedMetric == 'Specific') {
              specificRuns = _allRuns
                  .where(
                    (r) =>
                        r.userId == selectedUser!.id &&
                        r.distanceClass == selectedDistance,
                  )
                  .toList();
              specificRuns.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add Comparison Data',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    // 1. Select Athlete
                    DropdownButtonFormField<User>(
                      decoration: const InputDecoration(labelText: 'Athlete'),
                      items: _allUsers
                          .map(
                            (u) =>
                                DropdownMenuItem(value: u, child: Text(u.name)),
                          )
                          .toList(),
                      initialValue: selectedUser,
                      onChanged: (val) {
                        setModalState(() {
                          selectedUser = val;
                          selectedDistance = null;
                          selectedMetric = null;
                          selectedSpecificRun = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // 2. Select Distance
                    if (selectedUser != null)
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Distance',
                        ),
                        items: availableDistances
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text('${d}m'),
                              ),
                            )
                            .toList(),
                        initialValue: selectedDistance,
                        onChanged: (val) {
                          setModalState(() {
                            selectedDistance = val;
                            selectedMetric = null;
                            selectedSpecificRun = null;
                          });
                        },
                      ),
                    const SizedBox(height: 12),

                    // 3. Select Metric
                    if (selectedDistance != null)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Metric'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Average',
                            child: Text('Average'),
                          ),
                          DropdownMenuItem(
                            value: 'PB',
                            child: Text('Personal Best'),
                          ),
                          DropdownMenuItem(
                            value: 'L5',
                            child: Text('Last 5 Average'),
                          ),
                          DropdownMenuItem(
                            value: 'L10',
                            child: Text('Last 10 Average'),
                          ),
                          DropdownMenuItem(
                            value: 'Specific',
                            child: Text('Specific Run'),
                          ),
                        ],
                        initialValue: selectedMetric,
                        onChanged: (val) {
                          setModalState(() {
                            selectedMetric = val;
                            selectedSpecificRun = null;
                          });
                        },
                      ),
                    const SizedBox(height: 12),

                    // 4a. Average Timeframe
                    if (selectedMetric == 'Average')
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Timeframe',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'All Time',
                            child: Text('All Time'),
                          ),
                          DropdownMenuItem(
                            value: 'Today',
                            child: Text('Today'),
                          ),
                          DropdownMenuItem(
                            value: 'Week',
                            child: Text('Last 7 Days'),
                          ),
                          DropdownMenuItem(
                            value: 'Month',
                            child: Text('Last 30 Days'),
                          ),
                        ],
                        initialValue: averageTimeframe,
                        onChanged: (val) =>
                            setModalState(() => averageTimeframe = val),
                      ),

                    // 4b. Specific Run Selection
                    if (selectedMetric == 'Specific')
                      DropdownButtonFormField<Run>(
                        decoration: const InputDecoration(
                          labelText: 'Select Run',
                        ),
                        items: specificRuns
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.name),
                              ),
                            )
                            .toList(),
                        initialValue: selectedSpecificRun,
                        onChanged: (val) =>
                            setModalState(() => selectedSpecificRun = val),
                      ),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed:
                          (selectedUser != null &&
                              selectedDistance != null &&
                              selectedMetric != null)
                          ? () {
                              _handleAddSeries(
                                selectedUser!,
                                selectedDistance!,
                                selectedMetric!,
                                averageTimeframe,
                                selectedSpecificRun,
                              );
                              Navigator.pop(context);
                            }
                          : null,
                      child: const Text('Add to Graph'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleAddSeries(
    User user,
    int distance,
    String metric,
    String? timeframe,
    Run? specificRun,
  ) {
    List<Run> targetRuns = _allRuns
        .where((r) => r.userId == user.id && r.distanceClass == distance)
        .toList();
    targetRuns.sort(
      (a, b) => b.timestamp.compareTo(a.timestamp),
    ); // newest first

    if (targetRuns.isEmpty) return;

    String label = '${user.name} ${distance}m';
    List<Run> selectedRuns = [];

    switch (metric) {
      case 'Specific':
        if (specificRun == null) return;
        selectedRuns = [specificRun];
        label += ' - ${specificRun.name}';
        break;
      case 'PB':
        // Find fastest totalTimeSeconds
        Run pb = targetRuns.reduce(
          (curr, next) =>
              curr.totalTimeSeconds < next.totalTimeSeconds ? curr : next,
        );
        selectedRuns = [pb];
        label += ' - PB';
        break;
      case 'L5':
        selectedRuns = targetRuns.take(5).toList();
        label += ' - L5 Avg';
        break;
      case 'L10':
        selectedRuns = targetRuns.take(10).toList();
        label += ' - L10 Avg';
        break;
      case 'Average':
        if (timeframe == 'Today') {
          final now = DateTime.now();
          selectedRuns = targetRuns
              .where(
                (r) =>
                    r.timestamp.year == now.year &&
                    r.timestamp.month == now.month &&
                    r.timestamp.day == now.day,
              )
              .toList();
          label += ' - Today Avg';
        } else if (timeframe == 'Week') {
          final cutoff = DateTime.now().subtract(const Duration(days: 7));
          selectedRuns = targetRuns
              .where((r) => r.timestamp.isAfter(cutoff))
              .toList();
          label += ' - Week Avg';
        } else if (timeframe == 'Month') {
          final cutoff = DateTime.now().subtract(const Duration(days: 30));
          selectedRuns = targetRuns
              .where((r) => r.timestamp.isAfter(cutoff))
              .toList();
          label += ' - Month Avg';
        } else {
          selectedRuns = targetRuns;
          label += ' - All Time Avg';
        }
        break;
    }

    if (selectedRuns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No runs match this criteria.')),
      );
      return;
    }

    _ComparisonSeries? newSeries = _createSeriesFromRuns(
      label,
      _getNextColor(),
      selectedRuns,
    );
    if (newSeries != null) {
      setState(() {
        _seriesList.add(newSeries);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not average these runs (mismatched gate layouts).',
          ),
        ),
      );
    }
  }

  _ComparisonSeries? _createSeriesFromRuns(
    String label,
    Color color,
    List<Run> runs,
  ) {
    if (runs.isEmpty) return null;
    if (runs.length == 1) {
      return _generateSeriesFromRun(label, color, runs.first);
    }

    // To average runs, we must only average runs with the exact same number of gates
    // Find the most frequent gate count
    Map<int, int> gateCounts = {};
    for (var r in runs) {
      int count = r.gateTimeOffsets.length;
      gateCounts[count] = (gateCounts[count] ?? 0) + 1;
    }
    int modeGates = gateCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    List<Run> validRuns = runs
        .where((r) => r.gateTimeOffsets.length == modeGates)
        .toList();
    if (validRuns.isEmpty) {
      return null;
    }

    // Average gateTimeOffsets and nodeDistances
    List<int> avgOffsets = List.filled(modeGates, 0);
    List<double> avgDistances = List.filled(modeGates - 1, 0.0);

    for (var r in validRuns) {
      for (int i = 0; i < modeGates; i++) {
        avgOffsets[i] += r.gateTimeOffsets[i];
      }
      for (int i = 0; i < modeGates - 1; i++) {
        avgDistances[i] += (i < r.nodeDistances.length)
            ? r.nodeDistances[i]
            : 0.0;
      }
    }

    for (int i = 0; i < modeGates; i++) {
      avgOffsets[i] = (avgOffsets[i] / validRuns.length).round();
    }
    for (int i = 0; i < modeGates - 1; i++) {
      avgDistances[i] = avgDistances[i] / validRuns.length;
    }

    Run syntheticRun = Run(
      id: 'synthetic',
      name: 'synthetic',
      timestamp: DateTime.now(),
      nodeDistances: avgDistances,
      voltageData: [],
      gateTimeOffsets: avgOffsets,
      userId: null,
      distanceClass: validRuns.first.distanceClass,
    );

    return _generateSeriesFromRun(label, color, syntheticRun);
  }

  _ComparisonSeries _generateSeriesFromRun(String label, Color color, Run run) {
    final vels = run.segmentVelocities;
    final accels = run.segmentAccelerations;
    final times = run.cumulativeTimeSeconds;
    final positions = run.positionProfile;

    List<FlSpot> pSpots = [];
    List<FlSpot> vSpots = [];
    List<FlSpot> aSpots = [];

    for (int i = 0; i < times.length; i++) {
      if (i < positions.length) pSpots.add(FlSpot(times[i], positions[i]));
      if (i < vels.length) vSpots.add(FlSpot(times[i], vels[i]));
      if (i < accels.length) aSpots.add(FlSpot(times[i], accels[i]));
    }

    return _ComparisonSeries(
      label: label,
      color: color,
      positionSpots: pSpots,
      velocitySpots: vSpots,
      accelerationSpots: aSpots,
      maxTime: times.isNotEmpty ? times.last : 0.0,
    );
  }

  Widget _buildChart(
    String title,
    String unit,
    List<LineChartBarData> barData,
    double maxX,
  ) {
    if (barData.isEmpty) {
      return Center(
        child: Text(
          'Add data series below to begin comparing.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    double maxY = 0;
    double minY = double.infinity;
    for (var series in barData) {
      for (var spot in series.spots) {
        if (spot.y > maxY) {
          maxY = spot.y;
        }
        if (spot.y < minY) {
          minY = spot.y;
        }
      }
    }
    if (minY == double.infinity) {
      minY = 0;
    }

    maxY = maxY + (maxY.abs() * 0.2);
    minY = minY < 0 ? minY - (minY.abs() * 0.2) : 0;
    if (maxY == 0) {
      maxY = 1;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$title ($unit)',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: barData,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          return LineTooltipItem(
                            'Time: ${touchedSpot.x.toStringAsFixed(2)}s\nValue: ${touchedSpot.y.toStringAsFixed(2)}',
                            TextStyle(
                              color: touchedSpot.bar.color ?? Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(1)}s',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    double globalMaxTime = 0;
    List<LineChartBarData> posBars = [];
    List<LineChartBarData> velBars = [];
    List<LineChartBarData> accBars = [];

    for (var s in _seriesList) {
      if (s.maxTime > globalMaxTime) globalMaxTime = s.maxTime;

      posBars.add(
        LineChartBarData(
          spots: s.positionSpots,
          color: s.color,
          isCurved: true,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      );

      velBars.add(
        LineChartBarData(
          spots: s.velocitySpots,
          color: s.color,
          isCurved: true,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      );

      accBars.add(
        LineChartBarData(
          spots: s.accelerationSpots,
          color: s.color,
          isCurved: true,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Runs')),
      body: Column(
        children: [
          SizedBox(
            height: 350,
            child: PageView(
              controller: _pageController,
              children: [
                _buildChart('Position Profile', 'm', posBars, globalMaxTime),
                _buildChart('Velocity Profile', 'm/s', velBars, globalMaxTime),
                _buildChart(
                  'Acceleration Profile',
                  'm/s²',
                  accBars,
                  globalMaxTime,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Swipe graphs to view Vel/Acc →',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const Divider(),
          Expanded(
            child: _seriesList.isEmpty
                ? const Center(child: Text('No data series added.'))
                : ListView.builder(
                    itemCount: _seriesList.length,
                    itemBuilder: (context, index) {
                      final s = _seriesList[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: s.color,
                          radius: 12,
                        ),
                        title: Text(s.label),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeSeries(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'comparison_fab',
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Series'),
      ),
    );
  }
}
