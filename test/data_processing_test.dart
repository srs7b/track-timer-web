import 'package:flutter_test/flutter_test.dart';
import 'package:tt_flutter/services/data_processing_service.dart';

void main() {
  group('DataProcessingService.parseNodeTimingData', () {
    test('correctly parses 5 unique nodes and normalizes time', () {
      const rawData = "1,1000,2,2500,3,4500,4,6000,5,8000";
      final offsets = DataProcessingService.parseNodeTimingData(rawData);

      expect(offsets.length, 5);
      // Normalized: t - 1000
      expect(offsets, [0, 1500, 3500, 5000, 7000]);
    });

    test('handles redundant hits by keeping the earliest one per node', () {
      // Node 2 has two hits: 2500 and 2600. Node 1 has a late hit too.
      const rawData = "1,1000,2,2500,3,4500,2,2600,4,6000,5,8000,1,9000";
      final offsets = DataProcessingService.parseNodeTimingData(rawData);

      expect(offsets.length, 5);
      expect(offsets, [0, 1500, 3500, 5000, 7000]);
    });

    test('throws FormatException if node count is not exactly 5', () {
      const rawData = "1,1000,2,2500,3,4500,4,6000"; // Only 4 nodes
      expect(
        () => DataProcessingService.parseNodeTimingData(rawData),
        throwsFormatException,
      );
    });

    test('throws FormatException if data format is invalid (odd number of parts)', () {
      const rawData = "1,1000,2,2500,3"; 
      expect(
        () => DataProcessingService.parseNodeTimingData(rawData),
        throwsFormatException,
      );
    });
  });
}
