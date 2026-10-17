part of 'top_enemies.dart';

/// TopEnemies 사망·등장 전환(300줄 한도로 나눔).
extension _EnemyTransitions on TopEnemies {
  /// HD 보스 맞음 흰빛은 0.25초에 한 번 0.07초만(계속 맞으면 늘 창백하던 것 — 첫 15분 점검).
  bool _bossFlash(int id, {required double now, required bool on}) {
    if (!on) return false;
    final at = _bossFlashAt[id];
    if (at == null || now - at > 250 || now < at) {
      _bossFlashAt[id] = now;
      return true;
    }
    return now - at < 70;
  }

  /// 보스 체력 층이 깨지면(TopBreak.track — 기본 3층) '부서짐': 조각 터짐·흔들림. 깨진 뒤 지난 ms(없으면 큰 값).
  double _crack(EnemyPose e, double clock) {
    final breaks = scene.topHits.breaks;
    if (breaks.track(e.id, e.hpRatio, clock)) {
      scene.topHits.shatter.burst(
        clock,
        Offset(e.drawX, e.drawY),
        radiusOf(e) * 0.6,
        0xFFEDE4D2,
        lite: scene.topHits.lite,
      );
      scene.shake.triggerPx(4, 260);
    }
    return breaks.crackAge(e.id, clock);
  }

  /// 잡몹 등장 톡: 0.3배 → 1.12배 → 1배.
  double _bornPop(double bk) => bk >= 1 ? 1 : (bk < 0.6 ? 0.3 + 0.82 * bk / 0.6 : 1.12 - 0.12 * (bk - 0.6) / 0.4);

  /// 보스 등장: 바다 밑에서 솟아오름 — 등장 연출 앞 60% 동안 0.35배 → 1.1배(튀어 오름) → 1배.
  double _rise(double clock) {
    final m = scene.moments;
    final age = clock - scene.topHits.glow.bossRiseAt;
    final dur = m.entryTotal * 0.6;
    if (age < 0 || age >= dur) return 1;
    final u = age / dur;
    return u < 0.7 ? 0.35 + 0.75 * (1 - (1 - u / 0.7) * (1 - u / 0.7)) : 1.1 - 0.1 * (u - 0.7) / 0.3;
  }

  /// 층이 깨진 뒤 1초 비틀(좌우로 흔들리며 잦아듦, S1).
  double _crackTilt(double age) => age < 1000 ? math.sin(age / 45) * 0.16 * (1 - age / 1000) : 0;

  /// 보스 출렁임은 잡몹의 35%(큰 그림이 과하게 늘어나지 않게).
  (double, double)? _soft((double, double)? s, bool boss) =>
      s == null || !boss ? s : (1 + (s.$1 - 1) * 0.35, 1 + (s.$2 - 1) * 0.35);

  /// 모션 v1 사망·등장 전환: 사라진 잡몹은 0.16초 납작하게 찌그러지며 사라지고, 막 나타난 자리엔 물 고리(절전이면 없음).
  void _transitions(Canvas c, {required bool under, required double clock, required bool lite}) {
    final last = under ? _lastUnder : _lastOver;
    if (!lite) {
      for (final MapEntry(:key, :value) in last.entries) {
        if (_seen.containsKey(key) || _dying.length >= 24) continue;
        _dying.add((value.$1, value.$2, value.$3, value.$4, clock));
      }
    }
    last
      ..clear()
      ..addAll(_seen);
    if (_born.length > 400) {
      _born.removeWhere((id, _) => !_lastUnder.containsKey(id) && !_lastOver.containsKey(id));
      _right.removeWhere((id, _) => !_born.containsKey(id));
    }
    if (under) return;
    _dying.removeWhere((d) => clock - d.$5 > TopEnemies._dieMs);
    for (final (spr, tx, ty, rot, at) in _dying) {
      final t = (clock - at) / TopEnemies._dieMs;
      c
        ..save()
        ..translate(tx, ty)
        ..rotate(rot)
        ..scale(1.25 + 0.35 * t, math.max(0.05, 0.65 * (1 - t)));
      _draw(c, spr, t < 0.45 ? _flashPaint : _atlasPaint);
      c.restore();
    }
    _rings.removeWhere((r) => clock - r.$3 > 300);
    for (final (x, y, at) in _rings) {
      final t = (clock - at) / 300;
      _ringPaint
        ..strokeWidth = 2 * (1 - t) + 0.5
        ..color = Color.fromRGBO(230, 248, 255, 0.85 * (1 - t));
      c.drawCircle(Offset(x, y), 4 + 10 * t, _ringPaint);
    }
  }
}
