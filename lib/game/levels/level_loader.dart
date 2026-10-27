import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/level.dart';
import 'progression.dart';

const levelAssetIds = <String>[
  'c01', 'c02', 'c03', 'c04', 'c05', 'c06',
  'c07', 'c08', 'c09', 'c10', 'c11', 'c12',
  'c13', 'c14', 'c15', 'c16', 'c17', 'c18',
  'c19', 'c20', 'c21', 'c22', 'c23', 'c24',
  'c25', 'c26', 'c27', 'c28', 'c29', 'c30',
  'f01', 'f02', 'f03', 'f04', 'f05', 'f06', 'f07', 'f08', 'f09', 'f10',
];

Future<LevelCatalog> loadLevels() async {
  final levels = <Level>[];
  for (final id in levelAssetIds) {
    final raw = await rootBundle.loadString('assets/levels/$id.json');
    levels.add(
      Level.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      ),
    );
  }
  return LevelCatalog(levels);
}
