import 'package:flutter_test/flutter_test.dart';
import 'package:iv_sentinel/core/models/bed_config.dart';

void main() {
  const base = BedConfig(
    id: 'abc',
    name: 'Bed 1',
    channelId: '123',
    apiKey: 'KEY1',
    lowThreshold: 30,
    critThreshold: 15,
  );

  group('BedConfig JSON round-trip', () {
    test('toJson / fromJson preserves all fields', () {
      final json = base.toJson();
      final restored = BedConfig.fromJson(json);
      expect(restored, equals(base));
    });

    test('fromJson uses default thresholds when missing', () {
      final json = {
        'id': 'x',
        'name': 'Bed X',
        'channelId': '999',
        'apiKey': 'K',
      };
      final config = BedConfig.fromJson(json);
      expect(config.lowThreshold, 30.0);
      expect(config.critThreshold, 15.0);
    });
  });

  group('BedConfig equality', () {
    test('same values are equal', () {
      const b2 = BedConfig(
        id: 'abc',
        name: 'Bed 1',
        channelId: '123',
        apiKey: 'KEY1',
        lowThreshold: 30,
        critThreshold: 15,
      );
      expect(base, equals(b2));
      expect(base.hashCode, equals(b2.hashCode));
    });

    test('different id is not equal', () {
      final b2 = base.copyWith(id: 'xyz');
      expect(base, isNot(equals(b2)));
    });

    test('different thresholds are not equal', () {
      final b2 = base.copyWith(lowThreshold: 25);
      expect(base, isNot(equals(b2)));
    });
  });

  group('BedConfig copyWith', () {
    test('unchanged fields are preserved', () {
      final copy = base.copyWith(name: 'Bed 2');
      expect(copy.name, 'Bed 2');
      expect(copy.id, base.id);
      expect(copy.channelId, base.channelId);
      expect(copy.lowThreshold, base.lowThreshold);
    });
  });
}
