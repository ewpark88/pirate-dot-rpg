import 'dart:convert';

import 'package:game_data/game_data.dart';

/// 배 순항(waves.top.cruise)을 뺀 표 원본 — 배가 가운데(피버 8자·보스전 비켜서기만)에 있다고 보고 다른 기전(접촉·예고·결투·피버
/// 모션)을 재는 시험용. 순항 자체는 ship_cruise_test.
Map<String, String> stillShipRaw() {
  final raw = Map<String, String>.of(rawTables);
  final w = jsonDecode(raw['waves']!) as Map<String, dynamic>;
  (w['top'] as Map<String, dynamic>).remove('cruise');
  raw['waves'] = jsonEncode(w);
  return raw;
}
