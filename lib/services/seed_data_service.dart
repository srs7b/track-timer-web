import 'dart:math';
import '../models/run_model.dart';
import '../models/user_model.dart';
import 'database_service.dart';
import 'mock_data_service.dart';

class SeedDataService {
  static final DatabaseService _db = DatabaseService();

  static Future<void> seedIfNecessary() async {
    final runs = await _db.getAllRuns();
    final users = await _db.getAllUsers();

    // Only seed if we are under-populated
    if (runs.length >= 25 && users.length >= 5) return;

    final random = Random();

    // 1. Ensure Athletes
    final athletes = [
      {'id': 'user_1', 'name': 'The Big Yahu', 'gender': 'M'},
      {'id': 'user_2', 'name': 'Solána Imani Rowe', 'gender': 'F'},
      {'id': 'user_3', 'name': 'Shéyaa Bin Abraham-Joseph', 'gender': 'M'},
      {'id': 'user_4', 'name': 'Sean Combs', 'gender': 'M'},
      {'id': 'user_5', 'name': 'Belcalis Marlenis Almánzar', 'gender': 'F'},
    ];

    for (var a in athletes) {
      final existingUser = await _db.getUser(a['id'] as String);
      if (existingUser == null) {
        await _db.saveUser(
          User(
            id: a['id'] as String,
            name: a['name'] as String,
            createdDate: DateTime.now().subtract(
              Duration(days: random.nextInt(30)),
            ),
            gender: a['gender'] as String,
          ),
        );
      }
    }

    // 2. Generate 5 runs per athlete
    final distances = [100, 200, 400];
    final allRuns = await _db.getAllRuns();
    final seededRunIds = allRuns
        .where((r) => r.id.startsWith('seed_'))
        .map((r) => r.id)
        .toSet();

    for (var a in athletes) {
      String userId = a['id'] as String;

      for (int i = 0; i < 5; i++) {
        String runId = 'seed_${userId}_$i';
        if (seededRunIds.contains(runId)) continue;

        int dist = distances[random.nextInt(distances.length)];

        // Typical times:
        // 100m: 10-15s
        // 200m: 21-30s
        // 400m: 45-60s
        int baseMs = (dist == 100) ? 10000 : (dist == 200 ? 21000 : 45000);
        int variance = random.nextInt(
          dist == 100 ? 5000 : (dist == 200 ? 9000 : 15000),
        );
        int durationMs = baseMs + variance;

        final mockData = MockDataService.generateMockRunData(
          durationMs: durationMs,
          numGates: 3,
        );
        List<int> offsets = mockData['trueGateOffsets'] as List<int>;

        // Scale distances for 2 segments (3 gates)
        double segDist = dist / 2.0;
        List<double> nodeDistances = [segDist, segDist];

        final run = Run(
          id: 'seed_${userId}_$i',
          name: '${dist}M Sprint',
          timestamp: DateTime.now().subtract(
            Duration(days: random.nextInt(14), hours: random.nextInt(24)),
          ),
          nodeDistances: nodeDistances,
          gateTimeOffsets: offsets,
          userId: userId,
          distanceClass: dist,
          notes: 'Pre-seeded prototype data',
        );

        await _db.saveRun(run);
      }
    }
  }
}
