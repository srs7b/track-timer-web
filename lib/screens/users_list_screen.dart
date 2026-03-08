import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/run_model.dart';
import '../services/database_service.dart';
import 'user_summary_screen.dart';

class _UserStats {
  final User user;
  final int runsLogged;
  final double avgPace;

  _UserStats({
    required this.user,
    required this.runsLogged,
    required this.avgPace,
  });
}

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final DatabaseService _db = DatabaseService();
  List<_UserStats> _userStats = [];
  bool _isLoading = true;
  int _sortColumnIndex = 1; // Default sort by name
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final users = await _db.getAllUsers();
    final allRuns = await _db.getAllRuns();

    Map<String, List<Run>> runsMap = {};
    for (var u in users) {
      runsMap[u.id] = [];
    }
    for (var r in allRuns) {
      if (runsMap.containsKey(r.userId)) {
        runsMap[r.userId]!.add(r);
      }
    }

    List<_UserStats> stats = [];
    for (var user in users) {
      final runs = runsMap[user.id] ?? [];
      final completedRuns = runs
          .where((r) => r.gateTimeOffsets.length >= 2)
          .toList();
      int logged = completedRuns.length;

      double totalTime = 0;
      double totalDist = 0;
      double avgPace = double.infinity;

      if (completedRuns.isNotEmpty) {
        for (var r in completedRuns) {
          totalTime += r.totalTimeSeconds;
          totalDist += r.totalEventDistance;
        }
        if (totalDist > 0) {
          avgPace = totalTime / (totalDist / 100.0);
        }
      }

      stats.add(_UserStats(user: user, runsLogged: logged, avgPace: avgPace));
    }

    if (mounted) {
      setState(() {
        _userStats = stats;
        _isLoading = false;
        _sortData();
      });
    }
  }

  void _sortData() {
    _userStats.sort((a, b) {
      int comparison = 0;
      if (_sortColumnIndex == 1) {
        // Name
        comparison = a.user.name.compareTo(b.user.name);
      } else if (_sortColumnIndex == 2) {
        // Pace/100m
        comparison = a.avgPace.compareTo(b.avgPace);
      } else if (_sortColumnIndex == 3) {
        // Runs Logged
        comparison = a.runsLogged.compareTo(b.runsLogged);
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortData();
    });
  }

  Future<void> _addUser() async {
    final TextEditingController controller = TextEditingController();
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Athlete'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter athlete name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final newUser = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: newName,
        createdDate: DateTime.now(),
        gender: 'Unknown',
      );
      await _db.saveUser(newUser);
      _loadData(); // Re-fetch all mapping stats
    }
  }

  Future<void> _deleteUser(User user) async {
    final bool confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Athlete?'),
            content: Text(
              'Are you sure you want to delete ${user.name} and ALL their associated runs? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await _db.deleteUser(user.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Athletes')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userStats.isEmpty
          ? const Center(child: Text('No athletes added yet.'))
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  sortColumnIndex: _sortColumnIndex > 0
                      ? _sortColumnIndex
                      : null,
                  sortAscending: _sortAscending,
                  columns: [
                    const DataColumn(label: Text('')), // Icon Column
                    DataColumn(label: const Text('Name'), onSort: _onSort),
                    DataColumn(
                      label: const Text('Pace/100m'),
                      onSort: _onSort,
                      numeric: true,
                    ),
                    DataColumn(
                      label: const Text('Runs Logged'),
                      onSort: _onSort,
                      numeric: true,
                    ),
                    const DataColumn(label: Text('')), // Delete Action
                  ],
                  rows: _userStats.map((stat) {
                    final user = stat.user;
                    final paceStr = stat.avgPace == double.infinity
                        ? '-'
                        : '${stat.avgPace.toStringAsFixed(2)}s';

                    return DataRow(
                      // Making the entire row tappable bounds to UserSummaryScreen
                      onSelectChanged: (_) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserSummaryScreen(user: user),
                          ),
                        ).then((_) => _loadData());
                      },
                      cells: [
                        DataCell(
                          CircleAvatar(
                            radius: 14,
                            child: Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(Text(user.name)),
                        DataCell(Text(paceStr)),
                        DataCell(Text('${stat.runsLogged}')),
                        DataCell(
                          user.id != 'default_user'
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.blueGrey,
                                    size: 20,
                                  ),
                                  onPressed: () => _deleteUser(user),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'users_list_fab',
        onPressed: _addUser,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
