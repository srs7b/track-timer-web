import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/run_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../theme/style_constants.dart';
import '../widgets/velocity_card.dart';
import '../widgets/velocity_button.dart';

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
      maxTime: times.isNotEmpty ? times.last : 0.0,
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
              final isAlreadyAdded = _seriesList.any((s) => s.id == run.id);
              return ListTile(
                enabled: !isAlreadyAdded,
                title: Text(run.name.toUpperCase(), style: VelocityTextStyles.body.copyWith(
                  color: isAlreadyAdded ? VelocityColors.textDim : VelocityColors.textBody,
                )),
                subtitle: Text('${run.distanceClass}M · ${run.totalTimeSeconds.toStringAsFixed(2)}S', style: VelocityTextStyles.dimBody),
                onTap: () {
                  _addSeriesToComparison(run.id, run.name, run);
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

    return Scaffold(
      backgroundColor: VelocityColors.black,
      appBar: AppBar(
        title: Text('TRACK.TIME', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textBody, letterSpacing: 4)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('COMPARISON ANALYSIS', style: VelocityTextStyles.subHeading.copyWith(letterSpacing: 2)),
                  if (_seriesList.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _seriesList.clear()),
                      child: Text('CLEAR ALL', style: VelocityTextStyles.technical.copyWith(color: Colors.redAccent, fontSize: 10)),
                    ),
                ],
              ),
            ),
            
            if (_seriesList.isEmpty)
              _buildEmptyState()
            else
              _buildComparisonContent(),
              
            const SizedBox(height: 24),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VelocityButton(
                label: 'ADD TO COMPARISON',
                onPressed: _seriesList.length < 4 ? _showAddComparisonDialog : null,
                icon: Icons.add,
              ),
            ),
            
            if (_seriesList.isNotEmpty) ...[
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('ACTIVE SERIES', style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: VelocityColors.textDim, letterSpacing: 1)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _seriesList.length,
                  itemBuilder: (context, index) {
                    final s = _seriesList[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildSeriesTrayItem(s),
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesTrayItem(_ComparisonSeries s) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VelocityColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.label, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                  style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: VelocityColors.textBody)
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _seriesList.removeWhere((item) => item.id == s.id)),
                child: Icon(Icons.close, size: 14, color: Colors.redAccent.withOpacity(0.7)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'MAX: ${s.maxTime.toStringAsFixed(2)}S', 
            style: VelocityTextStyles.dimBody.copyWith(fontSize: 8)
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return VelocityCard(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.compare_arrows, size: 48, color: VelocityColors.textDim),
            const SizedBox(height: 16),
            Text(
              'NO DATA SELECTED',
              style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textDim),
            ),
            const SizedBox(height: 8),
            Text(
              'Add specific runs or athlete patterns to begin comparison.',
              textAlign: TextAlign.center,
              style: VelocityTextStyles.dimBody.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonContent() {
    return Column(
      children: [
        SizedBox(
          height: 320,
          child: PageView(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentMetricPage = idx),
            children: [
              _buildChartCard('POSITION (m)'),
              _buildChartCard('VELOCITY (m/s)'),
              _buildChartCard('ACCELERATION (m/s²)'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentMetricPage == i ? VelocityColors.primary : VelocityColors.textDim.withOpacity(0.3),
            ),
          )),
        ),
      ],
    );
  }

  Widget _buildChartCard(String metricTitle) {
    List<LineChartBarData> bars = [];
    double maxX = 0;

    for (var s in _seriesList) {
      if (s.maxTime > maxX) maxX = s.maxTime;
      List<FlSpot> spots;
      if (_currentMetricPage == 0) spots = s.posSpots;
      else if (_currentMetricPage == 1) spots = s.velSpots;
      else spots = s.accelSpots;

      bars.add(LineChartBarData(
        spots: spots,
        color: s.color,
        isCurved: true,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: s.color.withOpacity(0.05)),
      ));
    }

    return VelocityCard(
      padding: const EdgeInsets.fromLTRB(8, 24, 24, 16),
      child: Column(
        children: [
          Text(metricTitle, style: VelocityTextStyles.technical.copyWith(fontSize: 10, letterSpacing: 2, color: VelocityColors.textDim)),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(color: VelocityColors.textDim.withOpacity(0.05), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (maxX > 0) ? (maxX / 5).clamp(0.5, 5.0) : 1.0,
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
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => VelocityColors.surfaceLight,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        final series = _seriesList[s.barIndex];
                        return LineTooltipItem(
                          '${series.label}: ${s.y.toStringAsFixed(2)}',
                          VelocityTextStyles.technical.copyWith(color: series.color, fontSize: 10),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
