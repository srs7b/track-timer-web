import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import '../services/database_service.dart';
import '../theme/style_constants.dart';
import '../widgets/velocity_card.dart';
import 'run_details_screen.dart';

class UserSummaryScreen extends StatefulWidget {
  final User user;

  const UserSummaryScreen({super.key, required this.user});

  @override
  State<UserSummaryScreen> createState() => _UserSummaryScreenState();
}

class _UserSummaryScreenState extends State<UserSummaryScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = true;
  List<Run> _allUserRuns = [];

  int _selectedDistance = 100;
  String _selectedTimeframe = 'All Time'; 
  DateTimeRange? _dateRange;
  late StreamSubscription<void> _dbSub;

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
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final allRuns = await _db.getAllRuns();
    if (mounted) {
      setState(() {
        _allUserRuns = allRuns.where((r) => r.userId == widget.user.id).toList();
        _isLoading = false;
      });
    }
  }

  List<Run> _getFilteredRuns() {
    List<Run> filtered = _allUserRuns
        .where((r) => r.distanceClass == _selectedDistance)
        .toList();

    final now = DateTime.now();
    if (_selectedTimeframe == 'Today') {
      filtered = filtered.where((r) => 
        r.timestamp.year == now.year && r.timestamp.month == now.month && r.timestamp.day == now.day
      ).toList();
    } else if (_selectedTimeframe == 'Week') {
      final cutoff = now.subtract(const Duration(days: 7));
      filtered = filtered.where((r) => r.timestamp.isAfter(cutoff)).toList();
    } else if (_selectedTimeframe == 'Month') {
      final cutoff = now.subtract(const Duration(days: 30));
      filtered = filtered.where((r) => r.timestamp.isAfter(cutoff)).toList();
    } else if (_selectedTimeframe == 'Date Range' && _dateRange != null) {
      filtered = filtered.where((r) =>
        (r.timestamp.isAfter(_dateRange!.start) || r.timestamp.isAtSameMomentAs(_dateRange!.start)) &&
        (r.timestamp.isBefore(_dateRange!.end.add(const Duration(days: 1))) || r.timestamp.isAtSameMomentAs(_dateRange!.end))
      ).toList();
    }

    filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: VelocityColors.black,
        body: Center(child: CircularProgressIndicator(color: VelocityColors.primary))
      );
    }

    final filteredRuns = _getFilteredRuns();

    double avgTime = 0;
    double fastest = double.infinity;
    double slowest = 0;
    double topSpeed = 0;

    for (var r in filteredRuns) {
      final time = r.totalTimeSeconds;
      avgTime += time;
      if (time < fastest) fastest = time;
      if (time > slowest) slowest = time;
      if (r.topSpeed > topSpeed) topSpeed = r.topSpeed;
    }
    if (filteredRuns.isNotEmpty) avgTime /= filteredRuns.length;

    return Scaffold(
      backgroundColor: VelocityColors.black,
      appBar: AppBar(
        title: Text('${widget.user.name.toUpperCase()} PROFILE', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textBody, letterSpacing: 2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Athena Style Profile Header
            VelocityCard(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: VelocityColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: VelocityColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: Center(
                      child: Text(
                        widget.user.name.substring(0, 1).toUpperCase(),
                        style: VelocityTextStyles.heading.copyWith(color: VelocityColors.primary, fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.user.name.toUpperCase(), style: VelocityTextStyles.heading.copyWith(fontSize: 20, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(
                          'ATHLETE ID: ${widget.user.id.toUpperCase()}', 
                          style: VelocityTextStyles.dimBody.copyWith(fontSize: 9, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Filters Section
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown<int>(
                    value: _selectedDistance,
                    items: [100, 200, 400].map((d) => DropdownMenuItem(value: d, child: Text('${d}M'))).toList(),
                    onChanged: (val) => setState(() => _selectedDistance = val ?? 100),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildFilterDropdown<String>(
                    value: _selectedTimeframe,
                    items: ['All Time', 'Today', 'Week', 'Month', 'Date Range'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                    onChanged: (val) async {
                      if (val == 'Date Range') {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(primary: VelocityColors.primary, onPrimary: Colors.black, surface: VelocityColors.surfaceLight),
                            ),
                            child: child!,
                          ),
                        );
                        if (range != null) {
                          setState(() {
                            _selectedTimeframe = val!;
                            _dateRange = range;
                          });
                        }
                      } else {
                        setState(() => _selectedTimeframe = val!);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Performance Stats
            Row(
              children: [
                Expanded(
                  child: VelocityCard(
                    child: _buildStatItem('FASTEST', filteredRuns.isEmpty ? '-' : '${fastest.toStringAsFixed(2)}s', VelocityColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: VelocityCard(
                    child: _buildStatItem('TOP SPEED', filteredRuns.isEmpty ? '-' : '${topSpeed.toStringAsFixed(1)} m/s', VelocityColors.secondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: VelocityCard(
                    child: _buildStatItem('AVG TIME', filteredRuns.isEmpty ? '-' : '${avgTime.toStringAsFixed(2)}s', VelocityColors.textBody),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: VelocityCard(
                    child: _buildStatItem('TOTAL RUNS', '${filteredRuns.length}', VelocityColors.textBody),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),

            // History Chart
            Text('CHRONOLOGICAL HISTORY', style: VelocityTextStyles.technical.copyWith(fontSize: 10, letterSpacing: 2, color: VelocityColors.textDim)),
            const SizedBox(height: 16),
            if (filteredRuns.isEmpty)
              SizedBox(
                height: 200,
                child: Center(child: Text('NO DATA FOUND', style: VelocityTextStyles.dimBody)),
              )
            else
              VelocityCard(
                padding: const EdgeInsets.fromLTRB(8, 24, 16, 12),
                child: SizedBox(
                  height: 260,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: slowest > 0 ? slowest + (slowest * 0.1) : 10.0,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => VelocityColors.surfaceLight,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final run = filteredRuns[group.x.toInt()];
                            return BarTooltipItem(
                              '${DateFormat.MMMd().format(run.timestamp)}\n${run.totalTimeSeconds.toStringAsFixed(2)}s',
                              VelocityTextStyles.technical.copyWith(color: VelocityColors.primary, fontSize: 10),
                            );
                          },
                        ),
                        touchCallback: (event, response) {
                          if (event is FlTapUpEvent && response != null && response.spot != null) {
                            final run = filteredRuns[response.spot!.touchedBarGroupIndex];
                            Navigator.push(context, MaterialPageRoute(builder: (context) => RunDetailsScreen(run: run))).then((_) => _loadData());
                          }
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              if (val.toInt() >= filteredRuns.length) return const SizedBox();
                              if (filteredRuns.length > 10 && val.toInt() % (filteredRuns.length ~/ 5) != 0) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(DateFormat.Md().format(filteredRuns[val.toInt()].timestamp), style: VelocityTextStyles.dimBody.copyWith(fontSize: 8)),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (val, meta) => Text('${val.toInt()}s', style: VelocityTextStyles.dimBody.copyWith(fontSize: 8))),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: VelocityColors.textDim.withValues(alpha: 0.05), strokeWidth: 1)),
                      borderData: FlBorderData(show: false),
                      barGroups: filteredRuns.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final t = entry.value.totalTimeSeconds;
                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: t,
                              color: t == fastest ? VelocityColors.primary : VelocityColors.secondary.withValues(alpha: 0.8),
                              width: 8,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                              backDrawRodData: BackgroundBarChartRodData(show: true, toY: slowest + (slowest * 0.1), color: VelocityColors.black.withValues(alpha: 0.2)),
                            ),
                          ],
                        );
                      }).toList(),
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

  Widget _buildFilterDropdown<T>({required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: VelocityColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VelocityColors.textDim.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: VelocityColors.surfaceLight,
          isExpanded: true,
          style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: VelocityColors.primary, fontWeight: FontWeight.bold),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: VelocityColors.textDim),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: VelocityTextStyles.dimBody.copyWith(fontSize: 8, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(value, style: VelocityTextStyles.heading.copyWith(fontSize: 20, color: valueColor)),
        ],
      ),
    );
  }

}
