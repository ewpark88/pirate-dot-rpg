import 'package:game_core/src/battle/gun.dart';
import 'package:game_data/game_data.dart';

/// 선원 [crewId]의 그 등급([rarity] 순번) 공격 — 계열 · 사다리 · 개성 aim · 등급별 aim · 등급 템포(rarityTempo)를 모두 반영.
/// UI 상세(연사 · 한 발 배율 표기)가 엔진과 같은 값을 쓰게 하는 공개 창(S4 요청 — Gun은 공개 API가 아님).
AttackDef crewAttack(GameTables t, String crewId, int rarity) => Gun.of(t, crewId, power: 1, rarity: rarity).attack;
