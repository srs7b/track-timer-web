import 'dart:math';

class MockDataService {
  /// Generates a realistic set of timing offsets for an athlete
  /// running past 5 gates (Start, 1/4, 1/2, 3/4, Finish).
  ///
  /// [durationMs] is the simulated total time of the run.
  ///
  /// Returns a Map containing the 'trueGateOffsets' and a simulated
  /// raw BLE string for testing the parser.
  static Map<String, dynamic> generateMockRunData({
    required int durationMs,
  }) {
    List<int> trueGateOffsets = [];
    final random = Random();

    // 5 gates: Start (0%), 25%, 50%, 75%, 100% of the distance.
    // For a real run, acceleration means the first segment takes longer.
    List<double> timeProportions = [0.0, 0.38, 0.61, 0.81, 1.0];

    for (double prop in timeProportions) {
      int peakTimeMs = (durationMs * prop).round();
      trueGateOffsets.add(peakTimeMs);
    }

    // Generate a mock BLE string: "node1,time1,node2,time2,..."
    // We'll use alphanumeric names to test the new generic parser.
    List<String> rawParts = [];
    List<String> nodeNames = ["GATE_START", "GATE_A", "GATE_B", "GATE_C", "GATE_FINISH"];

    for (int i = 0; i < trueGateOffsets.length; i++) {
      rawParts.add(nodeNames[i]);
      rawParts.add("${trueGateOffsets[i]}");
      
      // Inject a "recording error" (duplicate) with 30% chance for "GATE_A"
      if (i == 1 && random.nextDouble() < 0.3) {
        rawParts.add("GATE_A");
        rawParts.add("${trueGateOffsets[i] + 50}"); // 50ms later
      }
    }

    return {
      'trueGateOffsets': trueGateOffsets,
      'rawBleString': rawParts.join(','),
    };
  }
}
