import 'package:game_data/game_data.dart';

/// 환생 회차 하나의 카드 수입. 보스 카드는 기댓값(장수 × `bossDropRates`)으로 센다 — 등급별 수입을
/// 운과 무관하게 비교하려고(반복 보스 규칙 결정용, 2026-10-15 S1 요청). 시작 카드(옥토)는 따로.
class RunCards {
  /// 역대 최고를 처음 넘은 보스 / 환생 뒤 이미 깬 스테이지(bestStage 미만)의 보스.
  int newBosses = 0;
  int repeatBosses = 0;
  int starterCards = 0;
  int summons = 0;
  final newByRarity = <String, double>{};
  final repeatByRarity = <String, double>{};

  /// 보스 [stage]를 잡았다. [bestBefore]는 잡기 전의 역대 최고, [rebirths]는 지금까지 환생 횟수.
  void bossCleared(GameTables t, {required int stage, required int bestBefore, required int rebirths}) {
    final b = t.growth.bossCards;
    if (rebirths == 0 && b.isStarterStage(stage)) {
      starterCards++;
      return;
    }
    final repeat = rebirths > 0 && stage < bestBefore;
    final into = repeat ? repeatByRarity : newByRarity;
    if (repeat) {
      repeatBosses++;
    } else {
      newBosses++;
    }
    final n = b.countAt(stage);
    for (final e in t.rarities.bossDropRates.entries) {
      into[e.key] = (into[e.key] ?? 0) + n * e.value;
    }
  }

  static double sum(Map<String, double> m) => m.values.fold(0, (a, v) => a + v);

  Map<String, Object?> toJson() => {
    'newBosses': newBosses,
    'repeatBosses': repeatBosses,
    'starterCards': starterCards,
    'summons': summons,
    'newByRarity': newByRarity,
    'repeatByRarity': repeatByRarity,
  };
}
