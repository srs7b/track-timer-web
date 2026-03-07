import 'package:flutter/material.dart';
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
  List<Run> _userRuns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRuns();
  }

  Future<void> _loadUserRuns() async {
    setState(() => _isLoading = true);
    final runs = await _db.getRunsByUser(widget.user.id);
    setState(() {
      _userRuns = runs;
      _isLoading = false;
    });
  }

  Future<void> _deleteRun(String runId) async {
    await _db.deleteRun(runId);
    _loadUserRuns();
  }

  // Calculate statistics only for runs that actually have valid completed times
  List<Run> get _completedRuns =>
      _userRuns.where((r) => r.gateTimeOffsets.length >= 2).toList();

  String _getPersonalBest() {
    final valid = _completedRuns;
    if (valid.isEmpty) return "N/A";

    double pb = double.infinity;
    for (var r in valid) {
      if (r.totalTimeSeconds < pb) pb = r.totalTimeSeconds;
    }
    return '${pb.toStringAsFixed(2)}s';
  }

  String _getAverageTime() {
    final valid = _completedRuns;
    if (valid.isEmpty) return "N/A";

    double sum = 0;
    for (var r in valid) {
      sum += r.totalTimeSeconds;
    }
    return '${(sum / valid.length).toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.user.name}\'s Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsHeader(),
                const Divider(),
                Expanded(
                  child: _userRuns.isEmpty
                      ? const Center(
                          child: Text('No runs recorded for this athlete.'),
                        )
                      : ListView.builder(
                          itemCount: _userRuns.length,
                          itemBuilder: (context, index) {
                            final run = _userRuns[index];
                            final dateStr = DateFormat.yMMMd().add_jm().format(
                              run.timestamp,
                            );
                            bool hasErrors = run.gateTimeOffsets.length != 5;

                            return ListTile(
                              leading: hasErrors
                                  ? const Icon(
                                      Icons.warning,
                                      color: Colors.orange,
                                    )
                                  : const Icon(
                                      Icons.timer,
                                      color: Colors.blueAccent,
                                    ),
                              title: Text(run.name),
                              subtitle: Text(
                                '${run.totalEventDistance.toStringAsFixed(1)}m • ${run.totalTimeSeconds.toStringAsFixed(2)}s\n$dateStr',
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _deleteRun(run.id),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RunDetailsScreen(run: run),
                                  ),
                                ).then((_) => _loadUserRuns());
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statBox('Total Runs', _userRuns.length.toString()),
          _statBox('Personal Best', _getPersonalBest()),
          _statBox('Avg Time', _getAverageTime()),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
      ],
    );
  }
}
