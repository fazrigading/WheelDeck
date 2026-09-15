import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';

/// The phone's ControlId wire values must match protocol/schema/controls.json.
void main() {
  test('ControlId wire values match the protocol schema', () {
    final schemaFile = _findFile('protocol/schema/controls.json');
    final schema = jsonDecode(schemaFile.readAsStringSync())
        as Map<String, dynamic>;
    final definitions = schema['definitions'] as Map<String, dynamic>;
    final controlId = definitions['ControlId'] as Map<String, dynamic>;
    final expected = (controlId['enum'] as List).cast<String>().toSet();

    final actual = ControlId.values.map((c) => c.wireValue).toSet();

    expect(actual, expected);
  });

  test('every ControlId has a documented wire value', () {
    for (final control in ControlId.values) {
      expect(control.wireValue, isNotEmpty, reason: control.name);
    }
  });
}

File _findFile(String relativePath) {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = File('${dir.path}/$relativePath');
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError('Could not locate $relativePath from ${Directory.current.path}');
}
