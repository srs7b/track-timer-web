import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/run_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../theme/style_constants.dart';

class _ComparisonSeries {
  final String id; // Source ID (run id or pattern id)
  final String label;
  final Color color;
  final List<FlSpot> posSpots;
  final List<FlSpot> velSpots;
  final List<FlSpot> accelSpots;
  final double maxTime;

  _ComparisonSeries({
    required this.id,
    required this.label,
    required this.color,
    required this.posSpots,
    required this.velSpots,
    required this.accelSpots,
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
  late StreamSubscription<void> _dbSub;

  int _currentMetricPage = 0;

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
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final runs = await _db.getAllRuns();
    final users = await _db.getAllUsers();
    if (mounted) {
      setState(() {
        _allRuns = runs;
        _allUsers = users;
        _isLoading = false;
      });
    }
  }

  void _addSeriesToComparison(String id, String label, Run run) {
    if (_seriesList.any((s) => s.id == id)) return;
    if (_seriesList.length >= 4) return;

    final colors = [
      VelocityColors.primary,
      VelocityColors.secondary,
      Colors.purpleAccent,
      Colors.orangeAccent,
    ];

    setState(() {
      _seriesList.add(_generateSeriesFromRun(
        id,
        label.toUpperCase(),
        colors[_seriesList.length % colors.length],
        run,
      ));
    });
  }

  _ComparisonSeries _generateSeriesFromRun(String id, String label, Color color, Run run) {
    final vels = run.segmentVelocities;
    final accels = run.segmentAccelerations;
    final times = run.cumulativeTimeSeconds;
    final positions = run.positionProfile;

    List<FlSpot> posSpots = [];
    List<FlSpot> velSpots = [];
    List<FlSpot> accelSpots = [];

    double maxTime = times.isNotEmpty ? times.last : 0.0;
    
    // Interpolate for smooth graph (0.05s resolution)
    for (int i = 0; i < times.length; i++) {
      if (i < positions.length) posSpots.add(FlSpot(times[i], positions[i]));
      if (i < vels.length) velSpots.add(FlSpot(times[i], vels[i]));
      if (i < accels.length) accelSpots.add(FlSpot(times[i], accels[i]));
    }

    return _ComparisonSeries(
      id: id,
      label: label,
      color: color,
      posSpots: posSpots,
      velSpots: velSpots,
      accelSpots: accelSpots,
      maxTime: maxTime,
    );
  }

  Future<void> _showAddComparisonDialog() async {
    await showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 2,
        child: AlertDialog(
          backgroundColor: VelocityColors.surfaceLight,
          title: Text('ADD TO COMPARISON', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TabBar(
                  labelStyle: VelocityTextStyles.technical.copyWith(fontSize: 10),
                  labelColor: VelocityColors.primary,
                  unselectedLabelColor: VelocityColors.textDim,
                  indicatorColor: VelocityColors.primary,
                  tabs: [
                    Tab(text: 'SESSIONS'),
                    Tab(text: 'PATTERNS'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildSessionSelectionList(),
                      _buildPatternSelectionList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionSelectionList() {
    return _allRuns.isEmpty
        ? Center(child: Text('NO SESSIONS FOUND', style: VelocityTextStyles.dimBody))
        : ListView.builder(
            itemCount: _allRuns.length,
            itemBuilder: (context, index) {
              final run = _allRuns[index];
              final user = _allUsers.firstWhere((u) => u.id == run.userId, orElse: () => User(id: '', name: 'Athlete', createdDate: DateTime.now(), gender: ''));
              final isAlreadyAdded = _seriesList.any((s) => s.id == run.id);
              return ListTile(
                enabled: !isAlreadyAdded,
                title: Text('${user.name}: ${run.name}'.toUpperCase(), style: VelocityTextStyles.body.copyWith(
                  color: isAlreadyAdded ? VelocityColors.textDim : VelocityColors.textBody,
                )),
                subtitle: Text('${run.distanceClass}M · ${run.totalTimeSeconds.toStringAsFixed(2)}S', style: VelocityTextStyles.dimBody),
                onTap: () {
                  _addSeriesToComparison(run.id, '${user.name.split(' ').first}: ${run.distanceClass}m', run);
                  Navigator.pop(context);
                },
              );
            },
          );
  }

  Widget _buildPatternSelectionList() {
    return ListView.builder(
      itemCount: _allUsers.length,
      itemBuilder: (context, index) {
        final user = _allUsers[index];
        return ExpansionTile(
          title: Text(user.name.toUpperCase(), style: VelocityTextStyles.body),
          children: [
            _buildPatternItem(user, 'PERSONAL BEST', 100),
            _buildPatternItem(user, 'AVERAGE RUN', 100),
            _buildPatternItem(user, 'PERSONAL BEST', 200),
            _buildPatternItem(user, 'AVERAGE RUN', 200),
            _buildPatternItem(user, 'PERSONAL BEST', 400),
            _buildPatternItem(user, 'AVERAGE RUN', 400),
          ],
        );
      },
    );
  }

  Widget _buildPatternItem(User user, String type, int dist) {
    String patternId = '${user.id}_${type}_$dist';
    bool alreadyAdded = _seriesList.any((s) => s.id == patternId);

    return ListTile(
      dense: true,
      enabled: !alreadyAdded,
      title: Text('$type (${dist}M)', style: VelocityTextStyles.dimBody.copyWith(
        color: alreadyAdded ? VelocityColors.textDim : VelocityColors.textBody,
        fontSize: 11
      )),
      onTap: () async {
        final runs = _allRuns.where((r) => r.userId == user.id && r.distanceClass == dist).toList();
        if (runs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('NO DATA FOR THIS PATTERN')));
          return;
        }

        Run? patternRun;
        if (type == 'PERSONAL BEST') {
          runs.sort((a, b) => a.totalTimeSeconds.compareTo(b.totalTimeSeconds));
          patternRun = runs.first;
        } else {
          patternRun = _calculateAverageRun(runs, user, dist);
        }

        _addSeriesToComparison(patternId, '${user.name.split(' ').first} $type ($dist)', patternRun);
        Navigator.pop(context);
      },
    );
  }

  Run _calculateAverageRun(List<Run> runs, User user, int dist) {
    // Basic average: average the gate time offsets
    List<int> avgOffsets = [];
    int maxGates = runs.fold(0, (prev, r) => r.gateTimeOffsets.length > prev ? r.gateTimeOffsets.length : prev);
    
    for (int i = 0; i < maxGates; i++) {
      int sum = 0;
      int count = 0;
      for (var r in runs) {
        if (i < r.gateTimeOffsets.length) {
          sum += r.gateTimeOffsets[i];
          count++;
        }
      }
      avgOffsets.add(sum ~/ count);
    }

    return Run(
      id: 'avg_${user.id}_$dist',
      name: 'AVG $dist',
      timestamp: DateTime.now(),
      nodeDistances: runs.first.nodeDistances, // Assuming consistency for distance
      gateTimeOffsets: avgOffsets,
      userId: user.id,
      distanceClass: dist,
      notes: 'Computed average run',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: VelocityColors.black,
        body: Center(child: CircularProgressIndicator(color: VelocityColors.primary)),
      );
    }
    final activeMetric = ['TIME (S)', 'VELOCITY (M/S)', 'ACCEL (M/S²)'][_currentMetricPage];

    return Scaffold(
      backgroundColor: VelocityColors.black,
      appBar: AppBar(
        title: Text('TRACK.TIME', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textBody, letterSpacing: 4)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metric Switcher (Position, Velocity, Accel)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: VelocityColors.surfaceLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    _buildMetricTab(0, 'Position'),
                    _buildMetricTab(1, 'Velocity'),
                    _buildMetricTab(2, 'Accel'),
                  ],
                ),
              ),
            ),
            
            if (_seriesList.isEmpty)
              _buildEmptyState()
            else
              _buildChartCard(activeMetric),
              
            const SizedBox(height: 32),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('ACTIVE SERIES (${_seriesList.length.toString().padLeft(2, '0')})', style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: VelocityColors.textDim, letterSpacing: 2)),
            ),
            const SizedBox(height: 16),
            
            // Active Series List (Vertical Cards)
            ..._seriesList.map((s) => _buildSeriesCard(s)).toList(),
            
            const SizedBox(height: 16),
            
            // Add Data Series Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: _seriesList.length < 4 ? _showAddComparisonDialog : null,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: VelocityColors.textDim.withOpacity(0.2), style: BorderStyle.none), // Should be dashed, but we'll use a soft border
                    color: VelocityColors.surfaceLight.withOpacity(0.3),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.add_circle_outline, size: 24, color: VelocityColors.textDim),
                        const SizedBox(height: 8),
                        Text('ADD DATA SERIES', style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: VelocityColors.textDim, letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTab(int index, String label) {
    bool isSelected = _currentMetricPage == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentMetricPage = index),
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Center(
            child: Text(
              label, 
              style: VelocityTextStyles.body.copyWith(
                fontSize: 13, 
                color: isSelected ? Colors.black : VelocityColors.textBody,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeriesCard(_ComparisonSeries s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VelocityColors.surfaceLight,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.label, style: VelocityTextStyles.heading.copyWith(fontSize: 18, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text('100M DASH    ${s.maxTime.toStringAsFixed(2)}s', style: VelocityTextStyles.technical.copyWith(fontSize: 11, color: VelocityColors.textDim)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: VelocityColors.textDim, size: 20),
              onPressed: () => setState(() => _seriesList.removeWhere((item) => item.id == s.id)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VelocityColors.surfaceLight.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart, size: 48, color: VelocityColors.textDim),
            const SizedBox(height: 16),
            Text('CHART COMPARISON EMPTY', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textDim)),
            const SizedBox(height: 8),
            Text('Select at least one series to begin.', style: VelocityTextStyles.dimBody.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String metricTitle) {
    List<LineChartBarData> bars = [];
    double maxX = _seriesList.isNotEmpty 
        ? _seriesList.map((s) => s.maxTime).reduce((a, b) => a > b ? a : b) 
        : 10.0;

    for (var s in _seriesList) {
      List<FlSpot> spots;
      if (_currentMetricPage == 0) spots = s.posSpots;
      else if (_currentMetricPage == 1) spots = s.velSpots;
      else spots = s.accelSpots;

      bars.add(LineChartBarData(
        spots: spots,
        color: s.color,
        isCurved: true,
        curveSmoothness: 0.35,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: s.color.withOpacity(0.05)),
      ));
    }

    return Container(
      height: 350,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(8, 32, 24, 16),
      decoration: BoxDecoration(
        color: VelocityColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Legend
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 24),
            child: Row(
              children: _seriesList.map((s) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(s.label, style: VelocityTextStyles.technical.copyWith(fontSize: 8, color: VelocityColors.textDim)),
                  ],
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // Y-Axis label (rotated)
                Positioned(
                  left: -5,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(metricTitle, style: VelocityTextStyles.technical.copyWith(fontSize: 8, color: VelocityColors.textDim.withOpacity(0.5))),
                    ),
                  ),
                ),
                LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      drawHorizontalLine: true,
                      getDrawingHorizontalLine: (val) => FlLine(color: VelocityColors.textDim.withOpacity(0.05), strokeWidth: 1),
                      getDrawingVerticalLine: (val) => FlLine(color: VelocityColors.textDim.withOpacity(0.05), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: (maxX / 5).clamp(1.0, 50.0),
                          getTitlesWidget: (val, meta) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('${val.toStringAsFixed(1)}s', style: VelocityTextStyles.dimBody.copyWith(fontSize: 8)),
                          ),
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: VelocityTextStyles.dimBody.copyWith(fontSize: 8)),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: bars,
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                        return spotIndexes.map((index) {
                          return TouchedSpotIndicatorData(
                            FlLine(color: Colors.white.withOpacity(0.2), strokeWidth: 1, dashArray: [5, 5]),
                            FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: barData.color ?? Colors.white,
                              ),
                            ),
                          );
                        }).toList();
                      },
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => VelocityColors.surfaceLight,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((s) {
                            final series = _seriesList[s.barIndex];
                            return LineTooltipItem(
                              '${series.label}\n${s.x.toStringAsFixed(2)}s: ${s.y.toStringAsFixed(2)}',
                              VelocityTextStyles.technical.copyWith(color: series.color, fontSize: 10),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
