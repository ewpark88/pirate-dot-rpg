import 'dart:convert';

import 'package:game_data/game_data.dart';

/// 배 순항(waves.top.cruise)과 보스 회피(bossDuel.dodge·bossDodge)를 뺀 표 원본 — 배가 가운데(피버 8자·보스전 비켜서기만)에
/// 있다고 보고 다른 기전(접촉·예고·결투·피버 모션)을 재는 시험용. 순항은 ship_cruise_test, 회피는 boss_dodge_test.
Map<String, String> stillShipRaw() => _without(cruise: true);

/// 보스 회피만 뺀 표 원본(순항은 그대로) — 순항 시험이 회피 대시(옆으로 300/초)에 섞이지 않게.
Map<String, String> noDodgeRaw() => _without(cruise: false);

Map<String, String> _without({required bool cruise}) {
  final raw = Map<String, String>.of(rawTables);
  final w = jsonDecode(raw['waves']!) as Map<String, dynamic>;
  final top = w['top'] as Map<String, dynamic>;
  if (cruise) top.remove('cruise');
  top.remove('bossDodge');
  (top['bossDuel'] as Map<String, dynamic>?)?.remove('dodge');
  raw['waves'] = jsonEncode(w);
  return raw;
}
