import 'dart:convert';

class Run {
  final String id;
  final String name;
  final DateTime timestamp;
  final List<double> voltageData;
  final List<int> gateTimeOffsets; // ms from start
  final List<double> nodeDistances; // distances between successive gates (m)
  final String userId;
  final String? notes;

  Run({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.nodeDistances,
    required this.voltageData,
    required this.gateTimeOffsets,
    required this.userId,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'timestamp': timestamp.toIso8601String(),
      'nodeDistances': jsonEncode(nodeDistances),
      'voltageData': jsonEncode(voltageData),
      'gateTimeOffsets': jsonEncode(gateTimeOffsets),
      'userId': userId,
      'notes': notes,
    };
  }

  factory Run.fromMap(Map<String, dynamic> map) {
    // Backward compatibility for old runs that only had eventDistance (defaulted to 100)
    List<double> parsedDistances = [];
    if (map['nodeDistances'] != null) {
      parsedDistances = List<double>.from(
        jsonDecode(map['nodeDistances']).map((x) => x.toDouble()),
      );
    } else {
      int legacyDistance = map['eventDistance'] ?? 100;
      // Default to 4 segments of equal length if we only knew total distance
      int numSegments = 4;
      double segDist = legacyDistance / numSegments;
      parsedDistances = List.filled(numSegments, segDist);
    }

    return Run(
      id: map['id'],
      name: map['name'],
      timestamp: DateTime.parse(map['timestamp']),
      nodeDistances: parsedDistances,
      voltageData: List<double>.from(
        jsonDecode(map['voltageData']).map((x) => x.toDouble()),
      ),
      gateTimeOffsets: List<int>.from(
        jsonDecode(map['gateTimeOffsets']).map((x) => x.toInt()),
      ),
      userId: map['userId'] ?? 'default_user',
      notes: map['notes'],
    );
  }

  // Get total distance for display
  double get totalEventDistance =>
      nodeDistances.fold(0.0, (sum, dist) => sum + dist);

  // Helper methodologies for statistics
  double get totalTimeSeconds => gateTimeOffsets.isNotEmpty
      ? (gateTimeOffsets.last - gateTimeOffsets.first) / 1000.0
      : 0.0;

  List<double> get splitTimesSeconds {
    List<double> splits = [];
    for (int i = 0; i < gateTimeOffsets.length; i++) {
      if (i == 0) {
        splits.add(0.0); // Start gate represents 0.0 elapsed time
      } else {
        splits.add((gateTimeOffsets[i] - gateTimeOffsets[i - 1]) / 1000.0);
      }
    }
    return splits;
  }

  List<double> get cumulativeTimeSeconds {
    if (gateTimeOffsets.isEmpty) return [];
    List<double> cumulative = [0.0];
    for (int i = 1; i < gateTimeOffsets.length; i++) {
      cumulative.add((gateTimeOffsets[i] - gateTimeOffsets[0]) / 1000.0);
    }
    return cumulative;
  }

  List<double> get segmentVelocities {
    if (gateTimeOffsets.length < 2 || nodeDistances.isEmpty) return [];

    // Start with 0 m/s for the start gate
    List<double> velocities = [0.0];
    List<double> splits = splitTimesSeconds;

    // splits[0] is the start (typically 0s). Actual segments are indices 1..N
    // Segment logic: segment 1 relies on nodeDistances[0], segment 2 on nodeDistances[1], etc.
    for (int i = 1; i < splits.length; i++) {
      double timeDelta = splits[i];
      // nodeDistances array should map 1:1 with splits (excluding the 0th index)
      int distIndex = i - 1;
      double distanceForSegment = (distIndex < nodeDistances.length)
          ? nodeDistances[distIndex]
          : 0.0;
      velocities.add(timeDelta > 0 ? distanceForSegment / timeDelta : 0.0);
    }
    return velocities; // in m/s
  }

  List<double> get segmentAccelerations {
    List<double> vels = segmentVelocities;
    if (vels.length < 2) return [];

    List<double> splits = splitTimesSeconds;

    // Start with 0 m/s^2 for the start gate
    List<double> accelerations = [0.0];

    // Accel for first segment (from vels[0] to vels[1])
    if (splits.length > 1 && splits[1] > 0) {
      accelerations.add((vels[1] - vels[0]) / splits[1]);
    } else {
      accelerations.add(0.0);
    }

    // Accel for subsequent segments
    for (int i = 2; i < vels.length; i++) {
      double timeDelta = splits[i];
      accelerations.add(
        timeDelta > 0 ? (vels[i] - vels[i - 1]) / timeDelta : 0.0,
      );
    }
    return accelerations; // in m/s^2
  }
}
