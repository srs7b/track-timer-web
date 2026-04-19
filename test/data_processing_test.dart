import 'package:flutter_test/flutter_test.dart';
import 'package:tt_flutter/services/data_processing_service.dart';

void main() {
  group('DataProcessingService.parseNodeTimingData', () {
    test('correctly parses 5 unique alphanumeric nodes and normalizes time', () {
      const rawData = "START,1000,GATE_A,2500,GATE_B,4500,GATE_C,6000,FINISH,8000";
      final offsets = DataProcessingService.parseNodeTimingData(rawData);

      expect(offsets.length, 5);
      // Normalized: t - 1000
      expect(offsets, [0, 1500, 3500, 5000, 7000]);
    });

    test('handles redundant hits by keeping the earliest one per node (strings)', () {
      // GATE_A has two hits: 2500 and 2600. START has a late hit too.
      const rawData = "START,1000,GATE_A,2500,GATE_B,4500,GATE_A,2600,GATE_C,6000,FINISH,8000,START,9000";
      final offsets = DataProcessingService.parseNodeTimingData(rawData);

      expect(offsets.length, 5);
      expect(offsets, [0, 1500, 3500, 5000, 7000]);
    });

    test('throws FormatException if node count is not exactly 5', () {
      const rawData = "G1,1000,G2,2500,G3,4500,G4,6000"; // Only 4 nodes
      expect(
        () => DataProcessingService.parseNodeTimingData(rawData),
        throwsFormatException,
      );
    });

    test('throws FormatException if data format is invalid (odd number of parts)', () {
      const rawData = "G1,1000,G2,2500,G3"; 
      expect(
        () => DataProcessingService.parseNodeTimingData(rawData),
        throwsFormatException,
      );
    });

    test('throws FormatException if timestamp is non-numeric', () {
      const rawData = "G1,1000,G2,not_a_number,G3,4500,G4,6000,G5,7000"; 
      expect(
        () => DataProcessingService.parseNodeTimingData(rawData),
        throwsFormatException,
      );
    });
  });
}
