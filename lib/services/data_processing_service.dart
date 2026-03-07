class DataProcessingService {
  /// Detects peaks in a voltage array that exceed a certain threshold.
  ///
  /// Returns a list of time offsets (in milliseconds) where the peaks occurred.
  /// [sampleRateHz] defaults to 100, meaning each index is 10ms.
  /// [threshold] is the voltage above which we consider the beam broken.
  /// [minPeakDistanceMs] is the minimum time between legitimate peaks to avoid
  /// counting the same bodily obstruction (e.g., arms then torso) as multiple passes.
  static List<int> detectPeaks(
    List<double> voltages, {
    int sampleRateHz = 100,
    double threshold = 2.5,
    int minPeakDistanceMs = 1000,
  }) {
    List<int> peakOffsetsMs = [];
    int sampleDurationMs = (1000 / sampleRateHz).round();

    int lastPeakTimeMs = -minPeakDistanceMs; // Allow a peak at time 0

    for (int i = 0; i < voltages.length; i++) {
      if (voltages[i] > threshold) {
        int currentTimeMs = i * sampleDurationMs;

        // If enough time has passed since the last recorded peak
        if (currentTimeMs - lastPeakTimeMs >= minPeakDistanceMs) {
          peakOffsetsMs.add(currentTimeMs);
          lastPeakTimeMs = currentTimeMs;
        }
      }
    }

    return peakOffsetsMs;
  }
}
