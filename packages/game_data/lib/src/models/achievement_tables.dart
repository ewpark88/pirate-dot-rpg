import 'package:game_data/src/models/common.dart';

/// 업적 단계 하나: 진행 값이 target에 닿으면(lowerIsBetter면 이하) gems 젬.
typedef AchievementStep = ({int target, int gems});

/// 업적 하나(achievements.json — 요청 ui-achievements.md). [metric]은 진행 값 종류(economy/achievements.dart).
class AchievementDef {
  AchievementDef.fromJson(JsonReader j)
    : id = j.str('id'),
      nameKey = j.str('nameKey'),
      iconKey = j.str('iconKey'),
      metric = j.str('metric'),
      lowerIsBetter = j.raw['lowerIsBetter'] == true,
      steps = [for (final s in j.objs('steps')) (target: s.integer('target'), gems: s.integer('gems'))];

  final String id;
  final String nameKey;
  final String iconKey;
  final String metric;

  /// 짧을수록 좋은 값(러시 최고 기록 초) — 단계 목표가 줄어든다.
  final bool lowerIsBetter;
  final List<AchievementStep> steps;
}

class AchievementsTable {
  AchievementsTable.fromJson(JsonReader j)
    : achievements = j.objs('achievements').map(AchievementDef.fromJson).toList();

  final List<AchievementDef> achievements;

  AchievementDef? byId(String id) => achievements.where((a) => a.id == id).firstOrNull;

  /// 엔진이 셀 줄 아는 진행 값 종류. 새 metric은 여기와 achievementValue에 함께 더한다.
  static const metrics = {
    'kills',
    'bosses',
    'bestStage',
    'rebirths',
    'collection',
    'mythicCrews',
    'towerBest',
    'rushClears',
    'rushBestSec',
    'fevers',
    'ultimates',
    'dungeonSteps',
    'bounties',
    'summons',
    'shipLevel',
  };

  List<String> validate() {
    final e = <String>[];
    final ids = <String>{};
    for (final a in achievements) {
      expect(e, that: ids.add(a.id), message: 'achievements: id ${a.id} 중복');
      expect(e, that: metrics.contains(a.metric), message: 'achievements: ${a.id}의 metric ${a.metric}을 엔진이 모름');
      expect(e, that: a.steps.isNotEmpty, message: 'achievements: ${a.id} 단계 없음');
      for (var i = 0; i < a.steps.length; i++) {
        final s = a.steps[i];
        expect(e, that: s.gems > 0 && s.target > 0, message: 'achievements: ${a.id} 단계 ${i + 1} 목표·젬은 양수');
        if (i > 0) {
          final prev = a.steps[i - 1].target;
          final ordered = a.lowerIsBetter ? s.target < prev : s.target > prev;
          expect(e, that: ordered, message: 'achievements: ${a.id} 단계 목표 순서(lowerIsBetter면 줄어야)');
        }
      }
    }
    return e;
  }
}
