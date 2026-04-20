import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/run_model.dart';
import '../services/database_service.dart';
import '../services/navigation_provider.dart';
import 'edit_peaks_screen.dart';
import '../theme/style_constants.dart';
import '../widgets/velocity_card.dart';
import '../widgets/velocity_button.dart';

class RunDetailsScreen extends StatefulWidget {
  final Run run;

  const RunDetailsScreen({super.key, required this.run});

  @override
  State<RunDetailsScreen> createState() => _RunDetailsScreenState();
}

class _RunDetailsScreenState extends State<RunDetailsScreen> {
  final PageController _pageController = PageController();
  late Run _run;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _run = widget.run;
  }

  Future<void> _editName() async {
    final TextEditingController controller = TextEditingController(text: _run.name);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VelocityColors.surfaceLight,
        title: Text('EDIT SESSION NAME', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary)),
        content: TextField(
          controller: controller,
          style: VelocityTextStyles.body,
          decoration: const InputDecoration(
            hintText: 'Enter name',
            hintStyle: TextStyle(color: VelocityColors.textDim),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: VelocityColors.textDim)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: VelocityColors.primary)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('SAVE', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary)),
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
        gateTimeOffsets: _run.gateTimeOffsets,
        userId: _run.userId,
        distanceClass: _run.distanceClass,
        notes: _run.notes,
      );
      await DatabaseService().saveRun(updatedRun);
      setState(() => _run = updatedRun);
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
          backgroundColor: VelocityColors.surfaceLight,
          title: Text('EDIT SEGMENT DISTANCES', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(controllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextField(
                    controller: controllers[i],
                    style: VelocityTextStyles.body,
                    decoration: InputDecoration(
                      labelText: 'GATE $i to ${i + 1} (m)',
                      labelStyle: VelocityTextStyles.dimBody,
                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: VelocityColors.textDim)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: VelocityColors.primary)),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCEL', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textDim)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('UPDATE', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary)),
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
        gateTimeOffsets: _run.gateTimeOffsets,
        userId: _run.userId,
        distanceClass: _run.distanceClass,
        notes: _run.notes,
      );

      await DatabaseService().saveRun(updatedRun);
      setState(() => _run = updatedRun);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vels = _run.segmentVelocities;
    final accels = _run.segmentAccelerations;
    final times = _run.cumulativeTimeSeconds;
    final positions = _run.positionProfile;

    List<FlSpot> posSpots = [];
    List<FlSpot> velSpots = [];
    List<FlSpot> accelSpots = [];
    for (int i = 0; i < times.length; i++) {
      if (i < positions.length) posSpots.add(FlSpot(times[i], positions[i]));
      if (i < vels.length) velSpots.add(FlSpot(times[i], vels[i]));
      if (i < accels.length) accelSpots.add(FlSpot(times[i], accels[i]));
    }

    return Scaffold(
      backgroundColor: VelocityColors.black,
      appBar: AppBar(
        title: Text('TRACK.TIME', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textBody, letterSpacing: 4)),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart, color: VelocityColors.textBody),
            onPressed: () async {
              final Run? updatedRun = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditPeaksScreen(run: _run)),
              );
              if (updatedRun != null) setState(() => _run = updatedRun);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: VelocityColors.textBody),
            onPressed: _editName,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_run.gateTimeOffsets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'DATA ERROR: Unexpected node structure detected.',
                          style: VelocityTextStyles.technical.copyWith(color: Colors.redAccent, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            _buildSummarySection(),
            const SizedBox(height: 24),
            
            SizedBox(
              height: 300,
              child: PageView(
                controller: _pageController,
                children: [
                  _buildChartCard('POSITION PROFILE', posSpots, VelocityColors.primary, 'm'),
                  _buildChartCard('VELOCITY PROFILE', velSpots, VelocityColors.secondary, 'm/s'),
                  _buildChartCard('ACCELERATION PROFILE', accelSpots, Colors.purpleAccent, 'm/s²'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'SWIPE TO ANALYZE METRICS',
                style: VelocityTextStyles.dimBody.copyWith(fontSize: 8, letterSpacing: 2),
              ),
            ),
            
            const SizedBox(height: 32),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: VelocityButton(
                  label: 'ANALYZE WITH COACH',
                  icon: Icons.psychology,
                  onPressed: () {
                    final nav = Provider.of<NavigationProvider>(context, listen: false);
                    nav.setTab(4, runToAnalyze: _run);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final dateFormat = DateFormat('MMM dd, yyyy · HH:mm');
    final avgSpeed = _run.distanceClass / _run.totalTimeSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('SESSION ANALYSIS', style: VelocityTextStyles.subHeading.copyWith(letterSpacing: 2)),
        ),
        const SizedBox(height: 16),
        VelocityCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetric('SPRINT DISTANCE', '${_run.distanceClass}M'),
                  _buildMetric('TOTAL TIME', '${_run.totalTimeSeconds.toStringAsFixed(2)}S'),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: VelocityColors.textDim, thickness: 0.1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetric('AVG VELOCITY', '${avgSpeed.toStringAsFixed(2)}m/s'),
                  _buildMetric('DATE', dateFormat.format(_run.timestamp).toUpperCase()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('CONFIGURATION', style: VelocityTextStyles.dimBody.copyWith(fontSize: 9, letterSpacing: 1.5)),
        ),
        VelocityCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.straighten, color: VelocityColors.primary, size: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'GATES: ${_run.nodeDistances.map((d) => '${d.toStringAsFixed(1)}m').join(' | ')}',
                  style: VelocityTextStyles.technical.copyWith(fontSize: 11, color: VelocityColors.textDim),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 14, color: VelocityColors.textDim),
                onPressed: _editNodeDistances,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VelocityTextStyles.dimBody.copyWith(fontSize: 8, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: VelocityTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildChartCard(String title, List<FlSpot> spots, Color lineColor, String unit) {
    return VelocityCard(
      child: Column(
        children: [
          Text(title, style: VelocityTextStyles.technical.copyWith(fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 24),
          Expanded(child: _buildChart(spots, lineColor, unit)),
        ],
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

    return LineChart(
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
            curveSmoothness: 0.35,
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
    );
  }
}
