import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import 'run_details_screen.dart';
import 'settings_screen.dart';
import '../theme/style_constants.dart';
import '../widgets/velocity_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  List<Run> _runs = [];
  List<User> _users = [];
  bool _isLoading = true;
  String _filter = 'All';
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
    try {
      final runs = await _db.getAllRuns();
      final users = await _db.getAllUsers();
      if (mounted) {
        setState(() {
          _runs = runs..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _getTopSpeed(List<Run> runs) {
    if (runs.isEmpty) return 0.0;
    double maxSpeed = 0.0;
    for (var run in runs) {
      if (run.gateTimeOffsets.length < 2) continue;
      double speed = run.distanceClass / run.totalTimeSeconds;
      if (speed > maxSpeed) maxSpeed = speed;
    }
    return maxSpeed;
  }

  @override
  Widget build(BuildContext context) {
    List<Run> filteredRuns = _filter == 'All' 
        ? _runs 
        : _runs.where((r) => r.distanceClass.toString() == _filter).toList();

    return Scaffold(
      backgroundColor: VelocityColors.black,
      appBar: AppBar(
        title: Text('TRACK.TIME', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textBody, letterSpacing: 4)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: VelocityColors.textBody),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: VelocityColors.primary))
          : Column(
              children: [
                // Dashboard Summary
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildSummaryItem('TOTAL RUNS', filteredRuns.length.toString()),
                      const SizedBox(width: 16),
                      _buildSummaryItem('TOP SPEED', '${_getTopSpeed(filteredRuns).toStringAsFixed(2)}m/s', color: VelocityColors.primary),
                    ],
                  ),
                ),
                
                // Filter Bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: ['All', '100', '200', '400'].map((f) {
                      bool isSelected = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f == 'All' ? 'ALL SESSIONS' : '${f}M SPRINT', style: VelocityTextStyles.dimBody.copyWith(fontSize: 10, color: isSelected ? VelocityColors.black : VelocityColors.textDim)),
                          selected: isSelected,
                          onSelected: (val) => setState(() => _filter = f),
                          backgroundColor: VelocityColors.surfaceLight,
                          selectedColor: VelocityColors.textBody,
                          showCheckmark: false,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                // Run List
                Expanded(
                  child: filteredRuns.isEmpty
                      ? Center(child: Text('NO SESSIONS FOUND', style: VelocityTextStyles.dimBody))
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          itemCount: filteredRuns.length,
                          itemBuilder: (context, index) {
                            final run = filteredRuns[index];
                            final user = _users.firstWhere((u) => u.id == run.userId, orElse: () => User(id: '', name: 'Unknown', createdDate: DateTime.now(), gender: 'Other'));
                            return _buildRunCard(run, user);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: VelocityColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VelocityColors.textDim.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: VelocityTextStyles.dimBody.copyWith(fontSize: 10, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text(value, style: VelocityTextStyles.heading.copyWith(fontSize: 28, color: color ?? VelocityColors.textBody)),
          ],
        ),
      ),
    );
  }

  Widget _buildRunCard(Run run, User user) {
    final dateFormat = DateFormat('MMM dd, yyyy · HH:mm');
    final avgSpeed = (run.distanceClass ?? 100) / run.totalTimeSeconds;
    
    return VelocityCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RunDetailsScreen(run: run)),
        ).then((_) => _loadData());
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('${run.distanceClass}M SPRINT', style: VelocityTextStyles.subHeading.copyWith(letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(dateFormat.format(run.timestamp).toUpperCase(), style: VelocityTextStyles.dimBody.copyWith(fontSize: 10)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VelocityColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${run.totalTimeSeconds.toStringAsFixed(2)}S',
                  style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMetric('AVG VELOCITY', '${avgSpeed.toStringAsFixed(2)}m/s'),
              const SizedBox(width: 24),
              _buildMetric('ATHLETE', user.name.toUpperCase()),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'VIEW REPORT >',
              style: VelocityTextStyles.technical.copyWith(fontSize: 10, letterSpacing: 1, color: VelocityColors.textDim),
            ),
          ),
        ],
      ),
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
}
