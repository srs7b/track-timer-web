import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/run_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import 'edit_peaks_screen.dart';

class RunDetailsScreen extends StatefulWidget {
  final Run run;

  const RunDetailsScreen({super.key, required this.run});

  @override
  State<RunDetailsScreen> createState() => _RunDetailsScreenState();
}

class _RunDetailsScreenState extends State<RunDetailsScreen> {
  late Run _run;
  final PageController _pageController = PageController();

  List<User> _users = [];
  bool _isLoadingUsers = true;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _run = widget.run;
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await DatabaseService().getAllUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _editName() async {
    final TextEditingController controller = TextEditingController(
      text: _run.name,
    );
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Run Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _run.name) {
      final updatedRun = Run(
        id: _run.id,
        name: newName,
        timestamp: _run.timestamp,
        nodeDistances: _run.nodeDistances,
        voltageData: _run.voltageData,
        gateTimeOffsets: _run.gateTimeOffsets,
        userId: _run.userId,
        distanceClass: _run.distanceClass,
        notes: _run.notes,
      );
      await DatabaseService().saveRun(updatedRun);
      setState(() {
        _run = updatedRun;
      });
    }
  }

  Future<void> _editNodeDistances() async {
    List<TextEditingController> controllers = _run.nodeDistances
        .map((d) => TextEditingController(text: d.toStringAsFixed(1)))
        .toList();

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Segment Distances (m)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(controllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextField(
                    controller: controllers[i],
                    decoration: InputDecoration(
                      labelText: 'Segment ${i + 1}',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      List<double> newDistances = [];
      for (var c in controllers) {
        double? val = double.tryParse(c.text);
        newDistances.add(val ?? 0.0);
      }

      final updatedRun = Run(
        id: _run.id,
        name: _run.name,
        timestamp: _run.timestamp,
        nodeDistances: newDistances,
        voltageData: _run.voltageData,
        gateTimeOffsets: _run.gateTimeOffsets,
        userId: _run.userId,
        distanceClass: _run.distanceClass,
        notes: _run.notes,
      );

      await DatabaseService().saveRun(updatedRun);
      setState(() {
        _run = updatedRun;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vels = _run.segmentVelocities;
    final accels = _run.segmentAccelerations;
    final times = _run.cumulativeTimeSeconds;

    final positions = _run.positionProfile;

    // Create spots matching time to velocities and accelerations
    List<FlSpot> posSpots = [];
    List<FlSpot> velSpots = [];
    List<FlSpot> accelSpots = [];
    for (int i = 0; i < times.length; i++) {
      if (i < positions.length) posSpots.add(FlSpot(times[i], positions[i]));
      if (i < vels.length) velSpots.add(FlSpot(times[i], vels[i]));
      if (i < accels.length) accelSpots.add(FlSpot(times[i], accels[i]));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_run.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            tooltip: 'Edit Peaks',
            onPressed: () async {
              final Run? updatedRun = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditPeaksScreen(run: _run),
                ),
              );
              if (updatedRun != null) {
                setState(() {
                  _run = updatedRun;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Name',
            onPressed: _editName,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_run.gateTimeOffsets.length != 5)
              Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.deepOrange,
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        'Warning: Expected 5 gates, but detected ${_run.gateTimeOffsets.length}. Statistics might be inaccurate. Please edit the peaks.',
                        style: TextStyle(color: Colors.deepOrange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            _buildSummaryCard(),
            const SizedBox(height: 20),
            SizedBox(
              height: 400,
              child: PageView(
                controller: _pageController,
                children: [
                  _buildChartCard(
                    'Position Profile',
                    posSpots,
                    Colors.green,
                    'm',
                  ),
                  _buildChartCard(
                    'Velocity Profile',
                    velSpots,
                    Colors.blueAccent,
                    'm/s',
                  ),
                  _buildChartCard(
                    'Acceleration Profile',
                    accelSpots,
                    Colors.orangeAccent,
                    'm/s²',
                  ),
                  _buildRawDataCard('Raw Voltage Data', _run.voltageData),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Swipe for more graphs →',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoadingUsers)
              const Center(child: CircularProgressIndicator())
            else ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      decoration: const InputDecoration(labelText: 'Athlete'),
                      initialValue: _run.userId,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Unassigned'),
                        ),
                        ..._users.map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(u.name),
                          ),
                        ),
                      ],
                      onChanged: (val) async {
                        final updatedRun = Run(
                          id: _run.id,
                          name: _run.name,
                          timestamp: _run.timestamp,
                          nodeDistances: _run.nodeDistances,
                          voltageData: _run.voltageData,
                          gateTimeOffsets: _run.gateTimeOffsets,
                          userId: val,
                          distanceClass: _run.distanceClass,
                          notes: _run.notes,
                        );
                        await DatabaseService().saveRun(updatedRun);
                        if (mounted) setState(() => _run = updatedRun);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Distance'),
                      initialValue: _run.distanceClass,
                      items: const [
                        DropdownMenuItem(value: 100, child: Text('100m')),
                        DropdownMenuItem(value: 200, child: Text('200m')),
                        DropdownMenuItem(value: 400, child: Text('400m')),
                      ],
                      onChanged: (val) async {
                        if (val == null) return;

                        double totalDistance = _run.nodeDistances.fold(
                          0.0,
                          (sum, d) => sum + d,
                        );
                        if ((totalDistance - val).abs() > 10.0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Warning: Run node distances sum to ${totalDistance}m, which relates poorly to the ${val}m class.',
                              ),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }

                        final updatedRun = Run(
                          id: _run.id,
                          name: _run.name,
                          timestamp: _run.timestamp,
                          nodeDistances: _run.nodeDistances,
                          voltageData: _run.voltageData,
                          gateTimeOffsets: _run.gateTimeOffsets,
                          userId: _run.userId,
                          distanceClass: val,
                          notes: _run.notes,
                        );
                        await DatabaseService().saveRun(updatedRun);
                        if (mounted) setState(() => _run = updatedRun);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Text('Date: ${DateFormat.yMMMd().add_jm().format(_run.timestamp)}'),
            Row(
              children: [
                Text(
                  'Distances: ${_run.nodeDistances.map((d) => '${d.toStringAsFixed(1)}m').join(', ')}',
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: _editNodeDistances,
                  tooltip: 'Edit Distances',
                ),
              ],
            ),
            Text('Total Time: ${_run.totalTimeSeconds.toStringAsFixed(2)}s'),
            Text(
              'Top Speed: ${_run.segmentVelocities.isNotEmpty ? _run.segmentVelocities.reduce((a, b) => a > b ? a : b).toStringAsFixed(2) : "N/A"} m/s',
            ),
            if (_run.notes != null && _run.notes!.isNotEmpty) ...[
              const Divider(),
              Text('Notes: ${_run.notes}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(
    String title,
    List<FlSpot> spots,
    Color lineColor,
    String unit,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildChart(spots, lineColor, unit)),
          ],
        ),
      ),
    );
  }

  Widget _buildRawDataCard(String title, List<double> voltages) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildRawDataChart(voltages)),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<FlSpot> spots, Color lineColor, String unit) {
    if (spots.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("Not enough data to plot.")),
      );
    }

    double maxY = 0;
    double minY = double.infinity;
    double maxX = spots.isNotEmpty ? spots.last.x : 0;

    for (var spot in spots) {
      if (spot.y > maxY) maxY = spot.y;
      if (spot.y < minY) minY = spot.y;
    }

    // Add padding to Y axis
    maxY = maxY + (maxY.abs() * 0.2);
    minY = minY < 0
        ? minY - (minY.abs() * 0.2)
        : 0; // if accel is negative, show it

    return SizedBox(
      height: 250,
      width: double.infinity,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  return LineTooltipItem(
                    'Time: ${touchedSpot.x.toStringAsFixed(2)}s\nValue: ${touchedSpot.y.toStringAsFixed(2)} $unit',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY == 0 ? 1 : maxY, // Avoid 0 maxY
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 4,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.2),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
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
      ),
    );
  }

  Widget _buildRawDataChart(List<double> voltages) {
    if (voltages.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("No raw data available.")),
      );
    }

    double maxY = voltages.reduce((a, b) => a > b ? a : b);
    double minY = voltages.reduce((a, b) => a < b ? a : b);

    List<FlSpot> spots = [];
    int numBuckets = 500; // Fixed number of points to draw
    if (voltages.length <= numBuckets) {
      for (int i = 0; i < voltages.length; i++) {
        double msTime = (i * 10.0);
        spots.add(FlSpot(msTime, voltages[i]));
      }
    } else {
      // Max pooling over buckets to preserve spikes
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
          if (voltages[i] < minY) minY = voltages[i]; // track global min
        }

        double timeMax = (maxIndex * 10.0);
        double timeMin = (minIndex * 10.0);

        // Draw the envelope naturally up and down chronologically
        if (minIndex < maxIndex) {
          spots.add(FlSpot(timeMin, minInBucket));
          spots.add(FlSpot(timeMax, maxInBucket));
        } else if (maxIndex < minIndex) {
          spots.add(FlSpot(timeMax, maxInBucket));
          spots.add(FlSpot(timeMin, minInBucket));
        } else {
          spots.add(FlSpot(timeMax, maxInBucket));
        }
      }

      spots.sort((a, b) => a.x.compareTo(b.x));
    }

    return SizedBox(
      height: 250,
      width: double.infinity,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  // X is in milliseconds in raw data chart
                  return LineTooltipItem(
                    'Time: ${(touchedSpot.x / 1000).toStringAsFixed(2)}s\nVoltage: ${touchedSpot.y.toStringAsFixed(2)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          minX: 0,
          maxX: spots.isNotEmpty ? spots.last.x : 0,
          minY: minY - 0.5,
          maxY: maxY + 0.5,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: Colors.redAccent,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          extraLinesData: ExtraLinesData(
            extraLinesOnTop: true,
            verticalLines: _run.gateTimeOffsets.map((timeMs) {
              return VerticalLine(
                x: timeMs.toDouble(),
                color: Colors.green.withValues(alpha: 0.8),
                strokeWidth: 2,
                dashArray: [5, 5],
              );
            }).toList(),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${(value / 1000).toStringAsFixed(1)}s',
                    style: const TextStyle(fontSize: 10),
                  );
                },
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
          borderData: FlBorderData(show: true),
        ),
      ),
    );
  }
}
