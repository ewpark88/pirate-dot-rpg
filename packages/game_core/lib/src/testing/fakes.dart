import 'package:game_core/src/ports/ports.dart';

/// 손으로 돌리는 시계.
class ManualClock implements Clock {
  ManualClock(DateTime start) : _now = start.toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);

  void setTime(DateTime t) => _now = t.toUtc();
}

/// 메모리 세이브 저장소. 쓸 때마다 이전 본을 백업으로 옮긴다.
class MemorySaveStore implements SaveStore {
  MemorySaveStore({this.main, this.backup});

  String? main;
  String? backup;

  @override
  Future<String?> read() async => main;

  @override
  Future<String?> readBackup() async => backup;

  @override
  Future<void> write(String json) async {
    backup = main;
    main = json;
  }
}

/// 항상 준비되어 있고 즉시 보상하는 가짜 광고. [failing]이면 실패를 재현한다.
class InstantAds implements AdsPort {
  InstantAds({this.failing = false});

  bool failing;
  final List<AdPlacement> shown = [];

  @override
  bool isReady(AdPlacement placement) => !failing;

  @override
  Future<AdResult> show(AdPlacement placement) async {
    shown.add(placement);
    return failing ? AdResult.failed : AdResult.rewarded;
  }
}

/// 이벤트를 기록만 하는 분석.
class RecordingAnalytics implements AnalyticsPort {
  final List<(String, Map<String, Object>)> events = [];
  String? lastScreen;
  int? lastStage;

  @override
  void log(String event, [Map<String, Object> params = const {}]) => events.add((event, params));

  @override
  void setLastSeen({required String screen, required int stage}) {
    lastScreen = screen;
    lastStage = stage;
  }
}

/// 메모리 랭킹 (2차 화면 개발용).
class MemoryLeaderboard implements LeaderboardPort {
  final List<ScoreSubmission> submitted = [];

  @override
  Future<void> submit(ScoreSubmission s) async => submitted.add(s);

  @override
  Future<List<RankEntry>> top(Board board, {int limit = 100}) async {
    final scores = submitted.where((s) => s.board == board).toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (var i = 0; i < scores.length && i < limit; i++)
        RankEntry(rank: i + 1, nickname: 'player${i + 1}', value: scores[i].value),
    ];
  }

  @override
  Future<RankEntry?> me(Board board) async {
    final t = await top(board);
    return t.isEmpty ? null : t.first;
  }
}

/// 소리를 내지 않고 호출만 기록한다 (렌더 테스트용).
class SilentAudio implements AudioPort {
  final List<String> calls = [];
  double sfx = 1;
  double bgm = 1;

  @override
  void playSfx(String id, {int variant = 0, double pitch = 1}) => calls.add('sfx:$id:$variant');

  @override
  void playBgm(String id) => calls.add('bgm:$id');

  @override
  void stopBgm() => calls.add('bgm:stop');

  @override
  void setVolumes({required double sfx, required double bgm}) {
    this.sfx = sfx;
    this.bgm = bgm;
  }
}
