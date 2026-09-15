import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/rotation_mapper.dart';

void main() {
  group('mapRotationToSteering', () {
    test('zero drag maps to centered', () {
      expect(mapRotationToSteering(0, 900), 0.0);
    });

    test('half-range drag hits full lock', () {
      expect(mapRotationToSteering(450, 900), 1.0);
      expect(mapRotationToSteering(-450, 900), -1.0);
    });

    test('scales with selected degree', () {
      expect(mapRotationToSteering(90, 180), 1.0);
      expect(mapRotationToSteering(1260, 2520), 1.0);
      expect(mapRotationToSteering(225, 900), closeTo(0.5, 1e-9));
    });

    test('clamps beyond full lock', () {
      expect(mapRotationToSteering(1000, 900), 1.0);
      expect(mapRotationToSteering(-2000, 900), -1.0);
    });
  });

  group('circularDelta', () {
    test('wraps across the +/-180 seam', () {
      expect(circularDelta(170, -170), closeTo(20, 1e-9));
      expect(circularDelta(-170, 170), closeTo(-20, 1e-9));
    });

    test('plain deltas pass through', () {
      expect(circularDelta(10, 45), closeTo(35, 1e-9));
      expect(circularDelta(45, 10), closeTo(-35, 1e-9));
    });
  });
}
