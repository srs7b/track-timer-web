import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
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

  int _sortColumnIndex = 2; // Default to 100m
  bool _sortAscending = true;

  // Custom cycling sort for gender: M -> F -> All -> M...
  String _genderSortFilter = 'All';
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
    final users = await _db.getAllUsers();
    final runs = await _db.getAllRuns();

    List<_LeaderboardRow> calculatedRows = [];

    for (var u in users) {
      final userRuns = runs.where((r) => r.userId == u.id).toList();

      double? pb100;
      double? pb200;
      double? pb400;

      for (var r in userRuns) {
        if (r.gateTimeOffsets.length < 2) continue; // invalid run

        if (r.distanceClass == 100) {
          if (pb100 == null || r.totalTimeSeconds < pb100) {
            pb100 = r.totalTimeSeconds;
          }
        } else if (r.distanceClass == 200) {
          if (pb200 == null || r.totalTimeSeconds < pb200) {
            pb200 = r.totalTimeSeconds;
          }
        } else if (r.distanceClass == 400) {
          if (pb400 == null || r.totalTimeSeconds < pb400) {
            pb400 = r.totalTimeSeconds;
          }
        }
      }

      calculatedRows.add(
        _LeaderboardRow(
          user: u,
          best100: pb100,
          best200: pb200,
          best400: pb400,
          totalRuns: userRuns.length,
        ),
      );
    }

    setState(() {
      _rows = calculatedRows;
      _isLoading = false;
      _sortData();
    });
  }

  void _cycleGenderSort() {
    setState(() {
      if (_genderSortFilter == 'All') {
        _genderSortFilter = 'M';
      } else if (_genderSortFilter == 'M') {
        _genderSortFilter = 'F';
      } else {
        _genderSortFilter = 'All';
      }
      _sortData();
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortData();
    });
  }

  void _sortData() {
    _rows.sort((a, b) {
      int comparison = 0;
      if (_sortColumnIndex == 0) {
        // Name
        comparison = a.user.name.compareTo(b.user.name);
      } else if (_sortColumnIndex == 2) {
        // 100m
        double valA = a.best100 ?? double.infinity;
        double valB = b.best100 ?? double.infinity;
        comparison = valA.compareTo(valB);
      } else if (_sortColumnIndex == 3) {
        // 200m
        double valA = a.best200 ?? double.infinity;
        double valB = b.best200 ?? double.infinity;
        comparison = valA.compareTo(valB);
      } else if (_sortColumnIndex == 4) {
        // 400m
        double valA = a.best400 ?? double.infinity;
        double valB = b.best400 ?? double.infinity;
        comparison = valA.compareTo(valB);
      } else if (_sortColumnIndex == 5) {
        // Total Runs
        comparison = a.totalRuns.compareTo(b.totalRuns);
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  Future<void> _showAddAthleteDialog() async {
    final TextEditingController nameController = TextEditingController();
    String selectedGender = 'M';

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Athlete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedGender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Male')),
                  DropdownMenuItem(value: 'F', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) selectedGender = val;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final newUser = User(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  createdDate: DateTime.now(),
                  gender: selectedGender,
                );
                await _db.saveUser(newUser);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    List<_LeaderboardRow> displayedRows = _rows;
    if (_genderSortFilter != 'All') {
      displayedRows = _rows
          .where((r) => r.user.gender == _genderSortFilter)
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddAthleteDialog,
            tooltip: 'Add Athlete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 11.0,
            horizontalMargin: 12.0,
            sortColumnIndex: _sortColumnIndex == 1 ? null : _sortColumnIndex,
            sortAscending: _sortAscending,
            showCheckboxColumn: false,
            columns: [
              DataColumn(label: const Text('Name'), onSort: _onSort),
              DataColumn(
                label: Row(
                  children: [
                    const Text('Gen '),
                    InkWell(
                      onTap: _cycleGenderSort,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColorDark,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _genderSortFilter,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DataColumn(
                label: const Text('100m PB'),
                onSort: _onSort,
                numeric: true,
              ),
              DataColumn(
                label: const Text('200m PB'),
                onSort: _onSort,
                numeric: true,
              ),
              DataColumn(
                label: const Text('400m PB'),
                onSort: _onSort,
                numeric: true,
              ),
              DataColumn(
                label: const Text('Runs'),
                onSort: _onSort,
                numeric: true,
              ),
            ],
            rows: displayedRows.map((row) {
              return DataRow(
                onSelectChanged: (_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserSummaryScreen(user: row.user),
                    ),
                  ).then((_) => _loadData());
                },
                cells: [
                  DataCell(Text(row.user.name)),
                  DataCell(Text(row.user.gender)),
                  DataCell(
                    Text(
                      row.best100 == null
                          ? '-'
                          : '${row.best100!.toStringAsFixed(2)}s',
                    ),
                  ),
                  DataCell(
                    Text(
                      row.best200 == null
                          ? '-'
                          : '${row.best200!.toStringAsFixed(2)}s',
                    ),
                  ),
                  DataCell(
                    Text(
                      row.best400 == null
                          ? '-'
                          : '${row.best400!.toStringAsFixed(2)}s',
                    ),
                  ),
                  DataCell(Text('${row.totalRuns}')),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
