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
      voltageData: widget.run.voltageData,
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

  // Use max-pooling downsampling to preserve spikes on the UI
  List<FlSpot> _getVoltageDataSpots() {
    final voltages = widget.run.voltageData;
    if (voltages.isEmpty) return [];

    List<FlSpot> spots = [];
    double sampleRate = 100.0;

    int numBuckets = 500;
    if (voltages.length <= numBuckets) {
      for (int i = 0; i < voltages.length; i++) {
        double timeMs = (i / sampleRate) * 1000.0;
        spots.add(FlSpot(timeMs / 1000.0, voltages[i]));
      }
    } else {
      int step = (voltages.length / numBuckets).ceil();
      if (step < 1) step = 1;

      for (
        int startIndex = 0;
        startIndex < voltages.length;
        startIndex += step
      ) {
        int endIndex = startIndex + step;
        if (endIndex > voltages.length) endIndex = voltages.length;

        double maxInBucket = voltages[startIndex];
        int maxIndex = startIndex;
        double minInBucket = voltages[startIndex];
        int minIndex = startIndex;

        for (int i = startIndex + 1; i < endIndex; i++) {
          if (voltages[i] > maxInBucket) {
            maxInBucket = voltages[i];
            maxIndex = i;
          }
          if (voltages[i] < minInBucket) {
            minInBucket = voltages[i];
            minIndex = i;
          }
        }

        double timeMax = (maxIndex / sampleRate) * 1000.0;
        double timeMin = (minIndex / sampleRate) * 1000.0;

        if (minIndex < maxIndex) {
          spots.add(FlSpot(timeMin / 1000.0, minInBucket));
          spots.add(FlSpot(timeMax / 1000.0, maxInBucket));
        } else if (maxIndex < minIndex) {
          spots.add(FlSpot(timeMax / 1000.0, maxInBucket));
          spots.add(FlSpot(timeMin / 1000.0, minInBucket));
        } else {
          spots.add(FlSpot(timeMax / 1000.0, maxInBucket));
        }
      }
      spots.sort((a, b) => a.x.compareTo(b.x));
    }

    return spots;
  }

  // Draw vertical lines where the peaks currently are
  List<VerticalLine> _getPeakLines() {
    return _currentGateOffsets.map((offsetMs) {
      return VerticalLine(
        x: offsetMs / 1000.0,
        color: Colors.redAccent.withValues(alpha: 0.8),
        strokeWidth: 2,
        dashArray: [5, 5],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final spots = _getVoltageDataSpots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Peaks'),
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
              'Remove false peaks. Expected Gates: 5, Found: ${_currentGateOffsets.length}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _currentGateOffsets.length == 5
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 2.0,
                      ),
                      axisNameWidget: Text('Time (s)'),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  extraLinesData: ExtraLinesData(
                    verticalLines: _getPeakLines(),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: Colors.blueAccent,
                      barWidth: 1.5,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: _currentGateOffsets.length,
              itemBuilder: (context, index) {
                int offsetMs = _currentGateOffsets[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    'Peak at ${(offsetMs / 1000.0).toStringAsFixed(3)}s',
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.blueGrey,
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
