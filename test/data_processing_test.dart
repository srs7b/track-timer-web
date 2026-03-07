import 'package:flutter_test/flutter_test.dart';
import 'package:tt_flutter/services/data_processing_service.dart';

void main() {
  test('Peak detection identifies correctly spaced peaks above threshold', () {
    // 100Hz = 10ms per sample
    // Let's create an array of 200 samples (2000ms = 2s)
    List<double> voltages = List.filled(200, 1.0);

    // Peak 1 at index 50 (500ms)
    voltages[50] = 3.5;
    // Peak 2 at index 150 (1500ms)
    voltages[150] = 3.2;

    List<int> offsets = DataProcessingService.detectPeaks(
      voltages,
      sampleRateHz: 100,
      threshold: 2.5,
      minPeakDistanceMs: 500,
    );

    expect(offsets.length, 2);
    expect(offsets[0], 500);
    expect(offsets[1], 1500);
  });
}
