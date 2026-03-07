import 'dart:math';

class MockDataService {
  /// Generates a realistic array of voltage readings representing an athlete
  /// running past 5 gates (Start, 1/4, 1/2, 3/4, Finish).
  ///
  /// [durationMs] is the simulated total time of the run.
  /// [sampleRateHz] is how many voltage readings per second (default 100Hz = 10ms per reading).
  ///
  /// Returns a Map containing the 'voltageData' and the true 'gateTimeOffsets'
  /// for verification purposes.
  static Map<String, dynamic> generateMockRunData({
    required int durationMs,
    int sampleRateHz = 100,
  }) {
    int preRunDelayMs = 2000;
    int postRunDelayMs = 2000;
    int totalDurationMs = durationMs + preRunDelayMs + postRunDelayMs;

    int totalSamples = (totalDurationMs / 1000.0 * sampleRateHz).ceil();
    List<double> voltages = List.filled(totalSamples, 0.0);
    List<int> trueGateOffsets = [];
    final random = Random();

    // Baseline voltage is around 1.0V (laser hitting sensor unblocked)
    // Noise is around +/- 0.1V
    double baseline = 1.0;

    // When beam is blocked, voltage spikes up to ~3.3V (or drops to 0V depending on pull-up/pull-down).
    // Let's assume breaking the beam INCREASES voltage to ~3.0V.
    double peakVoltage = 3.0;

    for (int i = 0; i < totalSamples; i++) {
      voltages[i] = baseline + (random.nextDouble() * 0.2 - 0.1);
    }

    // 5 gates: Start (0%), 25%, 50%, 75%, 100% of the distance.
    // For a real run, acceleration means the first segment takes longer.
    // Simulate realistic time proportions.
    List<double> timeProportions = [0.0, 0.38, 0.61, 0.81, 1.0];

    for (double prop in timeProportions) {
      int peakTimeMs = preRunDelayMs + (durationMs * prop).round();
      // Ensure we don't go out of bounds for the last peak
      if (peakTimeMs >= totalDurationMs) {
        peakTimeMs = totalDurationMs - 1;
      }
      trueGateOffsets.add(peakTimeMs);

      int peakIndex = (peakTimeMs / 1000.0 * sampleRateHz).round();
      if (peakIndex >= totalSamples) peakIndex = totalSamples - 1;

      // Create a small "hump" for the peak spanning a few samples (e.g., foot blocks laser for 50ms)
      int humpSamples = (0.05 * sampleRateHz)
          .ceil(); // 50ms = 5 samples at 100Hz

      for (int i = 0; i < humpSamples; i++) {
        int idx = peakIndex + i;
        if (idx < totalSamples) {
          voltages[idx] = peakVoltage + (random.nextDouble() * 0.2 - 0.1);
        }
      }
    }

    // Occasionally insert 1 to 2 "false peaks" (noise spikes) to let user test deletion feature
    // Has a 60% chance to generate at least 1 noise peak.
    if (random.nextDouble() < 0.60) {
      int numFalsePeaks = random.nextInt(2) + 1; // 1 or 2
      for (int f = 0; f < numFalsePeaks; f++) {
        // Create false peak somewhere inside the actual run duration
        int falseTimeMs = preRunDelayMs + random.nextInt(durationMs);

        // Don't inject exactly on top of true peaks
        bool tooClose = trueGateOffsets.any(
          (t) => (t - falseTimeMs).abs() < 500,
        );
        if (!tooClose) {
          int peakIndex = (falseTimeMs / 1000.0 * sampleRateHz).round();
          if (peakIndex >= totalSamples) peakIndex = totalSamples - 1;

          int humpSamples = (random.nextDouble() * 0.08 * sampleRateHz)
              .ceil(); // 0 to 80ms spike
          for (int i = 0; i < humpSamples; i++) {
            int idx = peakIndex + i;
            if (idx < totalSamples) {
              voltages[idx] = peakVoltage + (random.nextDouble() * 0.2 - 0.1);
            }
          }
        }
      }
    }

    return {
      'voltageData': voltages,
      'trueGateOffsets': trueGateOffsets,
      'sampleRateHz': sampleRateHz,
    };
  }
}
