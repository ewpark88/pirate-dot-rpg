/// 장면의 작은 상태 객체들 (battle_scene.dart에서 나눔).
library;

/// 맞은 적의 번쩍임·넉백 상태.
class HitState {
  int id = 0;
  double flashMs = 0;
  double knockAgeMs = 0;
  double knockMs = 0;
  double dirX = 0;
  double dirY = 0;
  double px = 0;
}

/// 운영자 모드·테스트가 읽는 숫자들. 객체 하나를 계속 고쳐 쓴다.
class SceneStats {
  int enemies = 0;
  int projectiles = 0;
  int effects = 0;
  int numbers = 0;
  int coins = 0;
  int zones = 0;

  /// 지금까지 본 분열·부활 연출 수 (M3 확인용).
  int splitPops = 0;
  int revives = 0;

  /// 풀·재사용 버퍼가 만든 객체 수. 워밍업 뒤에는 변하지 않아야 한다.
  int pooledObjects = 0;
}
