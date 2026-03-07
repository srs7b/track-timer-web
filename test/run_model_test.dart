import 'package:flutter_test/flutter_test.dart';
import 'package:tt_flutter/models/run_model.dart';

void main() {
  test('Run model calculates correct split velocities', () {
    final run = Run(
      id: 'test',
      name: 'Test Run',
      timestamp: DateTime.now(),
      nodeDistances: [25.0, 25.0, 25.0, 25.0],
      voltageData: [],
      // 5 gates = 4 segments (25m each)
      gateTimeOffsets: [0, 2500, 5000, 7500, 10000],
      userId: 'test_user',
    );

    // Splits: 0, 2.5s, 2.5s, 2.5s, 2.5s
    // Segment velocities: 0, 10, 10, 10, 10 m/s
    final vels = run.segmentVelocities;
    expect(vels.length, 5);
    expect(vels, [0.0, 10.0, 10.0, 10.0, 10.0]);

    // Acceleration:
    // Seg 1 (from 0 to 10 m/s in 2.5s) = 4 m/s^2
    // Seg 2, 3, 4 (constant 10 m/s) = 0 m/s^2
    final accels = run.segmentAccelerations;
    expect(accels.length, 5);
    expect(accels, [0.0, 4.0, 0.0, 0.0, 0.0]);
  });
}
