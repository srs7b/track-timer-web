import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/run_model.dart';
import '../services/database_service.dart';

class EditPeaksScreen extends StatefulWidget {
  final Run run;

  const EditPeaksScreen({super.key, required this.run});

  @override
  State<EditPeaksScreen> createState() => _EditPeaksScreenState();
}

class _EditPeaksScreenState extends State<EditPeaksScreen> {
  late List<int> _currentGateOffsets;

  @override
  void initState() {
    super.initState();
    // Copy the existing offsets so we can modify them
    _currentGateOffsets = List.from(widget.run.gateTimeOffsets);
  }

  void _removePeak(int index) {
    if (_currentGateOffsets.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot have less than 2 gates (Start & End)!'),
        ),
      );
      return;
    }

    setState(() {
      _currentGateOffsets.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    // Sort just in case editing messed up temporal order
    _currentGateOffsets.sort();

    final updatedRun = Run(
      id: widget.run.id,
      name: widget.run.name,
      timestamp: widget.run.timestamp,
      nodeDistances: widget.run.nodeDistances,
      gateTimeOffsets: _currentGateOffsets,
      userId: widget.run.userId,
      distanceClass: widget.run.distanceClass,
      notes: widget.run.notes,
    );

    await DatabaseService().saveRun(updatedRun);

    if (mounted) {
      Navigator.pop(context, updatedRun);
    }
  }

  // Draw vertical lines where the peaks currently are
  List<VerticalLine> _getPeakLines() {
    return _currentGateOffsets.map((offsetMs) {
      return VerticalLine(
        x: offsetMs / 1000.0,
        color: Colors.blueAccent.withValues(alpha: 0.8),
        strokeWidth: 3,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    double maxTime = _currentGateOffsets.isNotEmpty 
        ? (_currentGateOffsets.last / 1000.0) * 1.1 
        : 10.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Gates'),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Remove false hits. Expected Gates: 5, Found: ${_currentGateOffsets.length}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _currentGateOffsets.length == 5
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ),

          // Visual Timeline Chart
          SizedBox(
            height: 120,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 2.0,
                        getTitlesWidget: (val, meta) => Text('${val.toInt()}s', style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: maxTime,
                  minY: 0,
                  maxY: 1,
                  extraLinesData: ExtraLinesData(
                    verticalLines: _getPeakLines(),
                    horizontalLines: [
                      HorizontalLine(y: 0.5, color: Colors.grey.shade300, strokeWidth: 1),
                    ],
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _currentGateOffsets.map((ms) => FlSpot(ms / 1000.0, 0.5)).toList(),
                      color: Colors.transparent, // We only want the dots
                      barWidth: 0,
                      dotData: const FlDotData(
                        show: true,
                        getDotPainter: _getDotPainter,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: _currentGateOffsets.length,
              itemBuilder: (context, index) {
                int offsetMs = _currentGateOffsets[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    'Gate Hit at ${(offsetMs / 1000.0).toStringAsFixed(3)}s',
                  ),
                  subtitle: index > 0 
                    ? Text('Split: ${((offsetMs - _currentGateOffsets[index-1]) / 1000.0).toStringAsFixed(3)}s')
                    : const Text('Start Gate'),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _removePeak(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

FlDotPainter _getDotPainter(FlSpot spot, double xPercentage, LineChartBarData bar, int index) {
  return FlDotCirclePainter(
    radius: 6,
    color: Colors.blue,
    strokeWidth: 2,
    strokeColor: Colors.white,
  );
}
