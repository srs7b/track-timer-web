import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/run_model.dart';
import '../services/database_service.dart';

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  final DatabaseService _db = DatabaseService();
  List<Run> _allRuns = [];
  Run? _run1;
  Run? _run2;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRuns();
  }

  Future<void> _loadRuns() async {
    final runs = await _db.getAllRuns();
    setState(() {
      _allRuns = runs;
      if (runs.isNotEmpty) _run1 = runs[0];
      if (runs.length > 1) _run2 = runs[1];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay Runs')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSelectors(),
                  const SizedBox(height: 30),
                  Expanded(child: _buildChart()),
                ],
              ),
            ),
    );
  }

  Widget _buildSelectors() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: DropdownButton<Run>(
            value: _run1,
            isExpanded: true,
            hint: const Text('Select Run 1'),
            items: _allRuns
                .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                .toList(),
            onChanged: (val) => setState(() => _run1 = val),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: DropdownButton<Run>(
            value: _run2,
            isExpanded: true,
            hint: const Text('Select Run 2'),
            items: _allRuns
                .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                .toList(),
            onChanged: (val) => setState(() => _run2 = val),
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    if (_run1 == null && _run2 == null) {
      return const Text('Select at least one run.');
    }

    List<LineChartBarData> lines = [];
    double maxY = 0;

    if (_run1 != null) {
      final vels1 = _run1!.segmentVelocities;
      lines.add(_createLineData(vels1, Colors.blueAccent));
      for (var v in vels1) {
        if (v > maxY) maxY = v;
      }
    }

    if (_run2 != null) {
      final vels2 = _run2!.segmentVelocities;
      lines.add(_createLineData(vels2, Colors.redAccent));
      for (var v in vels2) {
        if (v > maxY) maxY = v;
      }
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY == 0 ? 1 : maxY + (maxY * 0.2), // Avoid 0 scaling issue
        lineBarsData: lines,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) => Text(
                'Seg ${val.toInt() + 1}',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  LineChartBarData _createLineData(List<double> vels, Color color) {
    List<FlSpot> spots = [];
    for (int i = 0; i < vels.length; i++) {
      spots.add(FlSpot(i.toDouble(), vels[i]));
    }
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 4,
      dotData: const FlDotData(show: true),
    );
  }
}
