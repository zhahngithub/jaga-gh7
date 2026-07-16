import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jaga/features/reports/domain/models/report_category.dart';

void main() {
  test('Dart category configuration mirrors shared categories JSON', () {
    final decoded =
        jsonDecode(File('shared/categories.json').readAsStringSync())
            as List<dynamic>;

    expect(decoded, hasLength(safetyCategories.length));
    for (final entry in decoded.cast<Map<String, dynamic>>()) {
      final category = safetyCategories[entry['id']];
      expect(category, isNotNull, reason: 'Missing category ${entry['id']}');
      expect(category!.polarity.name, entry['polarity']);
      expect(category.label, entry['label']);
      expect(category.sigmaMeters, entry['sigmaMeters']);
      expect(category.halfLifeHours, entry['halfLifeHours']);
      expect(category.ttlHours, entry['ttlHours']);
    }
  });
}
