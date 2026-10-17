part of 'battle_view.dart';

// 장면 모드 화면 상태(탑·보스 러시·요일 던전 — scene_mode.dart).

/// 탑 진행(HUD '심연 12층 · 2/3파'): 지금 층·이 층의 파(1부터)·층당 파 수.
class TowerView {
  const TowerView({required this.floor, required this.wave, required this.waves});

  factory TowerView.fromJson(Json j) =>
      TowerView(floor: j['floor'] as int, wave: j['wave'] as int, waves: j['waves'] as int);

  final int floor;
  final int wave;
  final int waves;

  Json toJson() => {'floor': floor, 'wave': wave, 'waves': waves};
}

/// 보스 러시 진행(HUD '보스 3/5 · 1:42'): 지금 보스(0부터)·전체 수·지난 틱.
class RushView {
  const RushView({required this.index, required this.total, required this.ticks});

  factory RushView.fromJson(Json j) =>
      RushView(index: j['index'] as int, total: j['total'] as int, ticks: j['ticks'] as int);

  final int index;
  final int total;
  final int ticks;

  Json toJson() => {'index': index, 'total': total, 'ticks': ticks};
}

/// 요일 던전 진행(HUD '관통의 날 3단계 · 1/2파'): 요일 묶음 id·단계·이 단계의 파(1부터, 보스면 waves + 1)·파 수.
class DungeonView {
  const DungeonView({required this.group, required this.step, required this.wave, required this.waves});

  factory DungeonView.fromJson(Json j) => DungeonView(
    group: j['group'] as String,
    step: j['step'] as int,
    wave: j['wave'] as int,
    waves: j['waves'] as int,
  );

  final String group;
  final int step;
  final int wave;
  final int waves;

  Json toJson() => {'group': group, 'step': step, 'wave': wave, 'waves': waves};
}
