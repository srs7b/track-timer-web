import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import '../services/database_service.dart';
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
  String _selectedTimeframe =
      'All Time'; // 'All Time', 'Today', 'Week', 'Month', 'Date Range'
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
    setState(() {
      _allUserRuns = allRuns.where((r) => r.userId == widget.user.id).toList();
      _isLoading = false;
    });
  }

  List<Run> _getFilteredRuns() {
    List<Run> filtered = _allUserRuns
        .where((r) => r.distanceClass == _selectedDistance)
        .toList();

    final now = DateTime.now();
    if (_selectedTimeframe == 'Today') {
      filtered = filtered
          .where(
            (r) =>
                r.timestamp.year == now.year &&
                r.timestamp.month == now.month &&
                r.timestamp.day == now.day,
          )
          .toList();
    } else if (_selectedTimeframe == 'Week') {
      final cutoff = now.subtract(const Duration(days: 7));
      filtered = filtered.where((r) => r.timestamp.isAfter(cutoff)).toList();
    } else if (_selectedTimeframe == 'Month') {
      final cutoff = now.subtract(const Duration(days: 30));
      filtered = filtered.where((r) => r.timestamp.isAfter(cutoff)).toList();
    } else if (_selectedTimeframe == 'Date Range' && _dateRange != null) {
      filtered = filtered
          .where(
            (r) =>
                (r.timestamp.isAfter(_dateRange!.start) ||
                    r.timestamp.isAtSameMomentAs(_dateRange!.start)) &&
                (r.timestamp.isBefore(
                      _dateRange!.end.add(const Duration(days: 1)),
                    ) ||
                    r.timestamp.isAtSameMomentAs(_dateRange!.end)),
          )
          .toList();
    }

    // Sort chronologically for the histogram
    filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filteredRuns = _getFilteredRuns();

    double avgTime = 0;
    double fastest = double.infinity;
    double slowest = 0;

    for (var r in filteredRuns) {
      final time = r.totalTimeSeconds;
      avgTime += time;
      if (time < fastest) fastest = time;
      if (time > slowest) slowest = time;
    }
    if (filteredRuns.isNotEmpty) avgTime /= filteredRuns.length;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.user.name} Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filters
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Distance'),
                    initialValue: _selectedDistance,
                    items: const [
                      DropdownMenuItem(value: 100, child: Text('100m')),
                      DropdownMenuItem(value: 200, child: Text('200m')),
                      DropdownMenuItem(value: 400, child: Text('400m')),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedDistance = val ?? 100),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Timeframe'),
                    initialValue: _selectedTimeframe,
                    items: const [
                      DropdownMenuItem(
                        value: 'All Time',
                        child: Text('All Time'),
                      ),
                      DropdownMenuItem(value: 'Today', child: Text('Today')),
                      DropdownMenuItem(value: 'Week', child: Text('Week')),
                      DropdownMenuItem(value: 'Month', child: Text('Month')),
                      DropdownMenuItem(
                        value: 'Date Range',
                        child: Text('Custom Range'),
                      ),
                    ],
                    onChanged: (val) async {
                      if (val == 'Date Range') {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (range != null) {
                          setState(() {
                            _selectedTimeframe = val!;
                            _dateRange = range;
                          });
                        }
                      } else {
                        setState(() {
                          _selectedTimeframe = val!;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(
                      'Average',
                      filteredRuns.isEmpty
                          ? '-'
                          : '${avgTime.toStringAsFixed(2)}s',
                    ),
                    _buildStatColumn(
                      'Fastest',
                      filteredRuns.isEmpty
                          ? '-'
                          : '${fastest.toStringAsFixed(2)}s',
                      color: Colors.green,
                    ),
                    _buildStatColumn(
                      'Slowest',
                      filteredRuns.isEmpty
                          ? '-'
                          : '${slowest.toStringAsFixed(2)}s',
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Histogram
            Text(
              'Chronological History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (filteredRuns.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'No runs found for these filters.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              SizedBox(
                height: 300,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: slowest + (slowest * 0.1),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final run = filteredRuns[group.x.toInt()];
                          return BarTooltipItem(
                            '${DateFormat.MMMd().format(run.timestamp)}\n${run.totalTimeSeconds.toStringAsFixed(2)}s',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      touchCallback: (FlTouchEvent event, barTouchResponse) {
                        if (!event.isInterestedForInteractions ||
                            barTouchResponse == null ||
                            barTouchResponse.spot == null) {
                          return;
                        }
                        if (event is FlTapUpEvent) {
                          final index =
                              barTouchResponse.spot!.touchedBarGroupIndex;
                          final run = filteredRuns[index];
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RunDetailsScreen(run: run),
                            ),
                          ).then((_) => _loadData());
                        }
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value.toInt() >= filteredRuns.length) {
                              return const SizedBox();
                            }
                            final run = filteredRuns[value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat.Md().format(run.timestamp),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: filteredRuns.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final r = entry.value;
                      final t = r.totalTimeSeconds;

                      Color c = Colors.blueAccent;
                      if (filteredRuns.length > 1) {
                        if (t == fastest) {
                          c = Colors.green;
                        } else if (t == slowest) {
                          c = Colors.redAccent;
                        }
                      }

                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: t,
                            color: c,
                            width: 16,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
