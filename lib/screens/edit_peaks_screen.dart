import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/run_model.dart';
import '../services/database_service.dart';
import '../theme/style_constants.dart';
import '../widgets/velocity_card.dart';

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
    _currentGateOffsets = List.from(widget.run.gateTimeOffsets);
  }

  void _removePeak(int index) {
    if (_currentGateOffsets.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('MINIMUM 2 GATES REQUIRED (START/FINISH)'),
        ),
      );
      return;
    }

    setState(() {
      _currentGateOffsets.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
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
    if (mounted) Navigator.pop(context, updatedRun);
  }

  @override
  Widget build(BuildContext context) {
    double maxTime = _currentGateOffsets.isNotEmpty 
        ? (_currentGateOffsets.last / 1000.0) * 1.1 
        : 10.0;

    return Scaffold(
      backgroundColor: VelocityColors.black,
      appBar: AppBar(
        title: Text('REVIEW GATE PEAKS', style: VelocityTextStyles.technical.copyWith(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: Text('SAVE', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TELEMETRY CALIBRATION', style: VelocityTextStyles.subHeading.copyWith(letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(
                  'EXPECTED: ${widget.run.nodeDistances.length + 1} GATES · DETECTED: ${_currentGateOffsets.length}',
                  style: VelocityTextStyles.technical.copyWith(
                    fontSize: 10,
                    color: _currentGateOffsets.length == (widget.run.nodeDistances.length + 1) ? VelocityColors.primary : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),

          // Timeline Chart
          SizedBox(
            height: 160,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VelocityCard(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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
                          interval: 2.0,
                          getTitlesWidget: (val, meta) => Text('${val.toInt()}s', style: VelocityTextStyles.dimBody.copyWith(fontSize: 8)),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: maxTime,
                    minY: 0,
                    maxY: 1,
                    extraLinesData: ExtraLinesData(
                      verticalLines: _currentGateOffsets.map((ms) => VerticalLine(
                        x: ms / 1000.0,
                        color: VelocityColors.primary.withOpacity(0.4),
                        strokeWidth: 2,
                        dashArray: [4, 4],
                      )).toList(),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _currentGateOffsets.map((ms) => FlSpot(ms / 1000.0, 0.5)).toList(),
                        color: Colors.transparent,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, p, bar, i) => FlDotCirclePainter(
                            radius: 6,
                            color: VelocityColors.primary,
                            strokeWidth: 2,
                            strokeColor: VelocityColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('DETECTED GATE HITS', style: VelocityTextStyles.dimBody.copyWith(fontSize: 10, letterSpacing: 1.5)),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
              itemCount: _currentGateOffsets.length,
              itemBuilder: (context, index) {
                int offsetMs = _currentGateOffsets[index];
                double split = index > 0 ? (offsetMs - _currentGateOffsets[index-1]) / 1000.0 : 0.0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: VelocityCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: VelocityColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text('${index + 1}', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary, fontSize: 12))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                index == 0 ? 'START TRIGGER' : (index == _currentGateOffsets.length - 1 ? 'FINISH GATE' : 'SPLIT GATE'),
                                style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: VelocityColors.primary),
                              ),
                              Text('TIME: ${(offsetMs / 1000.0).toStringAsFixed(3)}s', style: VelocityTextStyles.body.copyWith(fontSize: 13)),
                            ],
                          ),
                        ),
                        if (index > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('SPLIT', style: VelocityTextStyles.dimBody.copyWith(fontSize: 8)),
                              Text('+${split.toStringAsFixed(2)}s', style: VelocityTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                          onPressed: () => _removePeak(index),
                        ),
                      ],
                    ),
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
