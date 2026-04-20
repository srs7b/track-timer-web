import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import 'run_details_screen.dart';
import 'settings_screen.dart';
import '../theme/style_constants.dart';

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
  
  // Advanced Filters
  String _timeFilter = 'All'; // All, 7, 30
  String _genderFilter = 'All'; // All, M, F
  String? _athleteIdFilter; // User ID or null for 'All'
  
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

  bool _isPB(Run run) {
    // A run is a PB if it is the fastest for that athlete at that distance
    final athleteRuns = _runs.where((r) => r.userId == run.userId && r.distanceClass == run.distanceClass).toList();
    if (athleteRuns.isEmpty) return false;
    
    double bestTime = athleteRuns.map((r) => r.totalTimeSeconds).reduce((a, b) => a < b ? a : b);
    return run.totalTimeSeconds <= bestTime;
  }

  @override
  Widget build(BuildContext context) {
    // Apply Filters
    List<Run> filteredRuns = _runs.where((run) {
      // 1. Time Filter
      if (_timeFilter != 'All') {
        final days = int.parse(_timeFilter);
        final cutoff = DateTime.now().subtract(Duration(days: days));
        if (run.timestamp.isBefore(cutoff)) return false;
      }
      
      final user = _users.firstWhere((u) => u.id == run.userId, orElse: () => User(id: '', name: '', createdDate: DateTime.now(), gender: 'Other'));
      
      // 2. Gender Filter
      if (_genderFilter != 'All' && user.gender != _genderFilter) return false;
      
      // 3. Athlete Filter
      if (_athleteIdFilter != null && run.userId != _athleteIdFilter) return false;
      
      return true;
    }).toList();

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter Tray
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildPillFilter(
                        icon: Icons.calendar_today_outlined, 
                        label: _timeFilter == 'All' ? 'All Time' : 'Last $_timeFilter Days',
                        onTap: () => _showTimePicker(),
                        isSelected: _timeFilter != 'All',
                      ),
                      const SizedBox(width: 12),
                      _buildPillFilter(
                        label: 'Gender: $_genderFilter',
                        onTap: () => _showGenderPicker(),
                        isSelected: _genderFilter != 'All',
                      ),
                      const SizedBox(width: 12),
                      _buildPillFilter(
                        label: 'Athlete: ${_users.firstWhere((u) => u.id == _athleteIdFilter, orElse: () => User(id: '', name: 'All', createdDate: DateTime.now(), gender: '')).name}',
                        onTap: () => _showAthletePicker(),
                        isSelected: _athleteIdFilter != null,
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('RECORDS INDEX', style: VelocityTextStyles.technical.copyWith(fontSize: 12, letterSpacing: 1.5, color: VelocityColors.textDim)),
                      Text('IDX-${filteredRuns.length.toString().padLeft(3, '0')}', style: VelocityTextStyles.technical.copyWith(fontSize: 8, color: VelocityColors.textDim.withValues(alpha: 0.5))),
                    ],
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
                            return _buildRecordCard(run, user);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildPillFilter({IconData? icon, required String label, required VoidCallback onTap, bool isSelected = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? VelocityColors.textBody : VelocityColors.black,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: VelocityColors.textDim.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? VelocityColors.black : VelocityColors.textBody),
              const SizedBox(width: 8),
            ],
            Text(label, style: VelocityTextStyles.body.copyWith(fontSize: 12, color: isSelected ? VelocityColors.black : VelocityColors.textBody, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: isSelected ? VelocityColors.black : VelocityColors.textDim),
          ],
        ),
      ),
    );
  }

  void _showTimePicker() {
    _showPicker('TIME RANGE', {
      'All': 'All Time',
      '7': 'Last 7 Days',
      '30': 'Last 30 Days',
    }, (val) => setState(() => _timeFilter = val));
  }

  void _showGenderPicker() {
    _showPicker('GENDER', {
      'All': 'All Genders',
      'M': 'Male',
      'F': 'Female',
    }, (val) => setState(() => _genderFilter = val));
  }

  void _showAthletePicker() {
    final Map<String, String> options = {'All': 'All Athletes'};
    for (var u in _users) {
      options[u.id] = u.name;
    }
    _showPicker('SELECT ATHLETE', options, (val) => setState(() => _athleteIdFilter = val == 'All' ? null : val));
  }

  void _showPicker(String title, Map<String, String> options, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VelocityColors.surfaceLight,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: VelocityTextStyles.technical.copyWith(fontSize: 12, letterSpacing: 2)),
            const SizedBox(height: 16),
            ...options.entries.map((e) => ListTile(
              title: Text(e.value, style: VelocityTextStyles.body, textAlign: TextAlign.center),
              onTap: () {
                onSelect(e.key);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(Run run, User user) {
    final dateFormat = DateFormat('MMM dd, yyyy · HH:mm:ss');
    final bool isPB = _isPB(run);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RunDetailsScreen(run: run)),
          ).then((_) => _loadData());
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: VelocityColors.surfaceLight,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${user.gender} / ${run.distanceClass}M DASH', style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: VelocityColors.textDim)),
                        const SizedBox(height: 12),
                        Text(user.name, style: VelocityTextStyles.heading.copyWith(fontSize: 24, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${run.totalTimeSeconds.toStringAsFixed(2)}s', style: VelocityTextStyles.heading.copyWith(fontSize: 24)),
                      if (isPB) ...[
                        const SizedBox(height: 4),
                        Text('NEW PB', style: VelocityTextStyles.technical.copyWith(fontSize: 8, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white, thickness: 0.05, height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateFormat.format(run.timestamp).toUpperCase(), style: VelocityTextStyles.technical.copyWith(fontSize: 9, color: VelocityColors.textDim)),
                  Row(
                    children: [
                      Icon(Icons.share_outlined, size: 18, color: VelocityColors.textDim),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () => _db.deleteRun(run.id),
                        child: Icon(Icons.delete_outline, size: 18, color: VelocityColors.textDim)
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
