import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../theme/style_constants.dart';
import 'user_summary_screen.dart';

class _LeaderboardRow {
  final User user;
  final double? best100;
  final double? best200;
  final double? best400;
  final int totalRuns;

  _LeaderboardRow({
    required this.user,
    required this.best100,
    required this.best200,
    required this.best400,
    required this.totalRuns,
  });
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = true;
  List<_LeaderboardRow> _rows = [];
  String _genderSortFilter = 'All';
  String _activeSortMetric = '100M'; // 100M, 200M, 400M, RUNS
  late StreamSubscription<void> _dbSub;
  double? _globalBest100, _globalBest200, _globalBest400;
  int _globalMaxRuns = 0;

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
    final users = await _db.getAllUsers();
    final runs = await _db.getAllRuns();

    List<_LeaderboardRow> calculatedRows = [];
    double? g100, g200, g400;
    int gRuns = 0;

    for (var u in users) {
      final userRuns = runs.where((r) => r.userId == u.id).toList();
      double? pb100, pb200, pb400;

      for (var r in userRuns) {
        if (r.gateTimeOffsets.length < 2) continue;
        if (r.distanceClass == 100) {
          if (pb100 == null || r.totalTimeSeconds < pb100) pb100 = r.totalTimeSeconds;
        } else if (r.distanceClass == 200) {
          if (pb200 == null || r.totalTimeSeconds < pb200) pb200 = r.totalTimeSeconds;
        } else if (r.distanceClass == 400) {
          if (pb400 == null || r.totalTimeSeconds < pb400) pb400 = r.totalTimeSeconds;
        }
      }

      // Track global bests
      const double infinity = 999999.0;
      if (pb100 != null && pb100 < (g100 ?? infinity)) g100 = pb100;
      if (pb200 != null && pb200 < (g200 ?? infinity)) g200 = pb200;
      if (pb400 != null && pb400 < (g400 ?? infinity)) g400 = pb400;
      if (userRuns.length > gRuns) gRuns = userRuns.length;

      calculatedRows.add(_LeaderboardRow(
        user: u,
        best100: pb100,
        best200: pb200,
        best400: pb400,
        totalRuns: userRuns.length,
      ));
    }

    _sortRows(calculatedRows, _activeSortMetric);

    if (mounted) {
      setState(() {
        _rows = calculatedRows;
        _globalBest100 = g100;
        _globalBest200 = g200;
        _globalBest400 = g400;
        _globalMaxRuns = gRuns;
        _isLoading = false;
      });
    }
  }

  void _sortRows(List<_LeaderboardRow> list, String metric) {
    const double infinity = 999999.0;
    if (metric == '100M') {
      list.sort((a, b) => (a.best100 ?? infinity).compareTo(b.best100 ?? infinity));
    } else if (metric == '200M') {
      list.sort((a, b) => (a.best200 ?? infinity).compareTo(b.best200 ?? infinity));
    } else if (metric == '400M') {
      list.sort((a, b) => (a.best400 ?? infinity).compareTo(b.best400 ?? infinity));
    } else {
      list.sort((a, b) => b.totalRuns.compareTo(a.totalRuns));
    }
  }

  void _changeSort(String metric) {
    setState(() {
      _activeSortMetric = metric;
      _sortRows(_rows, metric);
    });
  }

  Future<void> _addAthlete() async {
    final nameController = TextEditingController();
    String gender = 'M';

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: VelocityColors.surfaceLight,
          title: Text('REGISTER NEW ATHLETE', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: VelocityTextStyles.body,
                decoration: InputDecoration(
                  labelText: 'FULL NAME',
                  labelStyle: VelocityTextStyles.dimBody,
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: VelocityColors.textDim)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: VelocityColors.primary)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('GENDER: ', style: VelocityTextStyles.dimBody),
                  const SizedBox(width: 16),
                  ActionChip(
                    label: Text('MALE', style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: gender == 'M' ? VelocityColors.black : VelocityColors.textBody)),
                    backgroundColor: gender == 'M' ? VelocityColors.primary : Colors.transparent,
                    onPressed: () => setDialogState(() => gender = 'M'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: Text('FEMALE', style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: gender == 'F' ? VelocityColors.black : VelocityColors.textBody)),
                    backgroundColor: gender == 'F' ? VelocityColors.primary : Colors.transparent,
                    onPressed: () => setDialogState(() => gender = 'F'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCEL', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textDim)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('REGISTER', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary)),
            ),
          ],
        ),
      ),
    );

    if (saved == true && nameController.text.isNotEmpty) {
      final newUser = User(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: nameController.text,
        createdDate: DateTime.now(),
        gender: gender,
      );
      await _db.saveUser(newUser);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<_LeaderboardRow> displayedRows = _rows;
    if (_genderSortFilter != 'All') {
      displayedRows = _rows.where((r) => r.user.gender == _genderSortFilter).toList();
    }

    return Scaffold(
      backgroundColor: VelocityColors.black,
      appBar: AppBar(
        title: Text('TRACK.TIME', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textBody, letterSpacing: 4)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined, color: VelocityColors.textBody),
            onPressed: _addAthlete,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: VelocityColors.primary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('GLOBAL RANKINGS', style: VelocityTextStyles.subHeading.copyWith(letterSpacing: 2)),
                      _buildGenderToggle(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildHeaderLabel('ATHLETE', flex: 3),
                      _buildHeaderLabel('100M', flex: 1, align: TextAlign.right, metric: '100M'),
                      _buildHeaderLabel('200M', flex: 1, align: TextAlign.right, metric: '200M'),
                      _buildHeaderLabel('400M', flex: 1, align: TextAlign.right, metric: '400M'),
                      _buildHeaderLabel('RUNS', flex: 1, align: TextAlign.right, metric: 'RUNS'),
                    ],
                  ),
                ),
                const Divider(color: VelocityColors.surfaceLight, height: 24, thickness: 0.5),
                Expanded(
                  child: ListView.builder(
                    itemCount: displayedRows.length,
                    itemBuilder: (context, index) {
                      final row = displayedRows[index];
                      return _buildRankItem(index + 1, row);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGenderToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: VelocityColors.surfaceLight,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: ['ALL', 'M', 'F'].map((g) {
          bool isSelected = (g == 'ALL' && _genderSortFilter == 'All') ||
              (g == _genderSortFilter);
          return GestureDetector(
            onTap: () => setState(() => _genderSortFilter = g == 'ALL' ? 'All' : g),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? VelocityColors.textBody : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                g,
                style: VelocityTextStyles.dimBody.copyWith(
                  color: isSelected ? VelocityColors.black : VelocityColors.textDim,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeaderLabel(String label, {int flex = 1, TextAlign align = TextAlign.left, String? metric}) {
    bool isActive = metric == _activeSortMetric;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: metric != null ? () => _changeSort(metric) : null,
        child: Column(
          crossAxisAlignment: align == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                label,
                textAlign: align,
                style: VelocityTextStyles.dimBody.copyWith(
                  fontSize: 8, 
                  letterSpacing: 1,
                  color: isActive ? VelocityColors.primary : VelocityColors.textDim,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isActive)
              Container(
                width: 12,
                height: 2,
                decoration: BoxDecoration(color: VelocityColors.primary, borderRadius: BorderRadius.circular(1)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankItem(int rank, _LeaderboardRow row) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => UserSummaryScreen(user: row.user)),
        ).then((_) => _loadData());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.user.name.toUpperCase(), style: VelocityTextStyles.technical.copyWith(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('RANK #$rank', style: VelocityTextStyles.dimBody.copyWith(fontSize: 10, letterSpacing: 1)),
                ],
              ),
            ),
            _buildMetricValue(row.best100, active: _activeSortMetric == '100M', isGlobalBest: row.best100 != null && row.best100 == _globalBest100),
            _buildMetricValue(row.best200, active: _activeSortMetric == '200M', isGlobalBest: row.best200 != null && row.best200 == _globalBest200),
            _buildMetricValue(row.best400, active: _activeSortMetric == '400M', isGlobalBest: row.best400 != null && row.best400 == _globalBest400),
            _buildMetricValue(row.totalRuns.toDouble(), isInt: true, active: _activeSortMetric == 'RUNS', isGlobalBest: row.totalRuns > 0 && row.totalRuns == _globalMaxRuns),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricValue(double? value, {bool isInt = false, bool active = false, bool isGlobalBest = false}) {
    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: active ? VelocityColors.primary.withOpacity(0.03) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          value == null ? '-' : (isInt ? value.toInt().toString() : value.toStringAsFixed(2)),
          textAlign: TextAlign.right,
          style: VelocityTextStyles.body.copyWith(
            fontWeight: active || isGlobalBest ? FontWeight.bold : FontWeight.normal,
            fontSize: isGlobalBest ? 13 : 12,
            color: value == null 
                ? VelocityColors.textDim 
                : (isGlobalBest ? VelocityColors.primary : (active ? VelocityColors.textBody : VelocityColors.textDim.withOpacity(0.8))),
          ),
        ),
      ),
    );
  }
}
