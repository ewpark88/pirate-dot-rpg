import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_bounty.dart';
import 'package:game_core/src/battle/topdown/top_tower.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';

// 장면 모드 공통부(platform-tower 5절): 본 전투(스테이지·파·골드·피버·돌발)를 멈추고 다른 장면을 여는 콘텐츠 —
// 현상금(top_bounty)·심연의 탑(top_tower). 뒤에 보스 러시·요일 던전도 여기 하나씩 더한다. battle_system은 이 세 함수만 부른다.

/// 전투 계산 전: 장면을 열거나(이번 틱은 화면 반영만) 끊긴 장면을 정리한 상태. 아무 장면도 아니면 null.
GameState? scenePrepare(GameState s, Field f, SystemContext ctx, {required bool fresh}) =>
    TopBounty.prepare(s, f, ctx, fresh: fresh) ?? TopTower.prepare(s, f, ctx, fresh: fresh);

/// 장면 한 틱이 끝난 뒤의 판정(본 판정·돌발 이벤트·피버를 건너뛴다).
GameState sceneResolve(GameState s, Field f, SystemContext ctx) =>
    f.bounty != null ? TopBounty.resolve(s, f, ctx) : TopTower.resolve(s, f, ctx);

/// 그만두기(RetreatBounty·RetreatTower) — 진행 중인 장면만.
GameState sceneRetreat(GameState s, Field f, SystemContext ctx) =>
    f.bounty != null ? TopBounty.retreat(s, f, ctx) : TopTower.retreat(s, f, ctx);
