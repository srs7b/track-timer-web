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
    int numGates = 3,
  }) {
    List<int> trueGateOffsets = [];
    final random = Random();
    // (Wait, actually I removed the block that used random). I'll just remove the variable.

    // Adjusted proportions for numGates:
    // 3 gates: Start (0.0), Middle (0.6), Finish (1.0)
    // 5 gates: [0.0, 0.38, 0.61, 0.81, 1.0]
    List<double> timeProportions = numGates == 3 
        ? [0.0, 0.62, 1.0] 
        : [0.0, 0.38, 0.61, 0.81, 1.0];

    for (double prop in timeProportions) {
      int peakTimeMs = (durationMs * prop).round();
      trueGateOffsets.add(peakTimeMs);
    }

    List<String> rawParts = [];
    List<String> nodeNames = numGates == 3 
        ? ["GATE_START", "GATE_MID", "GATE_FINISH"]
        : ["GATE_START", "GATE_A", "GATE_B", "GATE_C", "GATE_FINISH"];

    for (int i = 0; i < trueGateOffsets.length; i++) {
      rawParts.add(nodeNames[i]);
      rawParts.add("${trueGateOffsets[i]}");
      
      // Inject entry/leave hits (6 data points for 3 gates)
      if (numGates == 3) {
        rawParts.add(nodeNames[i]);
        rawParts.add("${trueGateOffsets[i] + 50}"); // 50ms later for leave event
      }
    }

    return {
      'trueGateOffsets': trueGateOffsets,
      'rawBleString': rawParts.join(','),
    };
  }
}
