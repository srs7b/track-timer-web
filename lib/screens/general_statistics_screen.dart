import 'package:flutter/material.dart';
import '../models/run_model.dart';
import '../services/database_service.dart';
import 'package:fl_chart/fl_chart.dart';

class GeneralStatisticsScreen extends StatefulWidget {
  const GeneralStatisticsScreen({super.key});

  @override
  State<GeneralStatisticsScreen> createState() =>
      _GeneralStatisticsScreenState();
}

class _GeneralStatisticsScreenState extends State<GeneralStatisticsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Run> _allRuns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final runs = await _db.getAllRuns();
    // Filter to only runs that have valid completed times (i.e. at least Start and End)
    setState(() {
      _allRuns = runs.where((r) => r.gateTimeOffsets.length >= 2).toList();
      _isLoading = false;
    });
  }

  double _getGlobalAverageTime() {
    if (_allRuns.isEmpty) return 0.0;
    double sum = 0;
    for (var r in _allRuns) {
      sum += r.totalTimeSeconds;
    }
    return sum / _allRuns.length;
  }

  Run? _getFastestRun() {
    if (_allRuns.isEmpty) return null;
    Run fastest = _allRuns.first;
    for (var r in _allRuns) {
      if (r.totalTimeSeconds < fastest.totalTimeSeconds) {
        fastest = r;
      }
    }
    return fastest;
  }

  double _getAverageTopSpeed() {
    if (_allRuns.isEmpty) return 0.0;
    double sumSpeeds = 0;
    int count = 0;
    for (var r in _allRuns) {
      final vels = r.segmentVelocities;
      if (vels.isNotEmpty) {
        sumSpeeds += vels.reduce((a, b) => a > b ? a : b);
        count++;
      }
    }
    return count > 0 ? sumSpeeds / count : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Global Statistics')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allRuns.isEmpty
          ? const Center(child: Text('No completed runs available.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 30),
                  Text(
                    'Recent Run Times (s)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  _buildTrendChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    final fastest = _getFastestRun();

    return Row(
      children: [
        Expanded(
          child: Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Avg Time',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_getGlobalAverageTime().toStringAsFixed(2)}s',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Record Time',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fastest != null
                        ? '${fastest.totalTimeSeconds.toStringAsFixed(2)}s'
                        : 'N/A',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Avg Speed',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_getAverageTopSpeed().toStringAsFixed(1)} m/s',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart() {
    // Show the last 10 runs as a trend
    final recentRuns = _allRuns.take(10).toList().reversed.toList();
    List<FlSpot> spots = [];

    double maxY = 0;
    double minY = double.infinity;

    for (int i = 0; i < recentRuns.length; i++) {
      double time = recentRuns[i].totalTimeSeconds;
      spots.add(FlSpot(i.toDouble(), time));
      if (time > maxY) maxY = time;
      if (time < minY) minY = time;
    }

    if (spots.isEmpty) return const SizedBox();

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (recentRuns.length - 1).toDouble(),
          minY: (minY - 1).clamp(0, double.infinity),
          maxY: maxY + 1,
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.purpleAccent,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}
