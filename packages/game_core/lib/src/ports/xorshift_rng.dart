import 'package:game_core/src/ports/ports.dart';

/// xorshift32. 앱과 테스트가 같은 구현을 쓴다(설계서 3.2).
class XorShiftRng implements Rng {
  /// 시드 0은 xorshift에서 멈추므로 다른 값으로 바꾼다.
  XorShiftRng(int seed) : _s = (seed & _mask) == 0 ? _fallbackSeed : seed & _mask;

  static const _mask = 0xFFFFFFFF;
  static const _fallbackSeed = 0x9E3779B9;
  static const _range = 4294967296.0; // 2^32

  int _s;

  @override
  int get state => _s;

  int _next() {
    var x = _s;
    x ^= (x << 13) & _mask;
    x ^= x >> 17;
    x ^= (x << 5) & _mask;
    return _s = x & _mask;
  }

  @override
  double nextDouble() => _next() / _range;

  @override
  int nextInt(int max) {
    if (max <= 0) throw RangeError.range(max, 1, null, 'max');
    return (nextDouble() * max).floor();
  }
}
