import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';

/// 운영자 '메모리' 줄 (S1·S5 폰 누수 추적, 2026-10-18): 이미지 캐시 크기·살아 있는 이미지 수를 2초마다.
/// 렌더 HD 시트(painter.top.memory() — S3)는 그 API가 main에 들어오면 같은 줄에 더한다.
class MemoryLine extends StatefulWidget {
  const MemoryLine({super.key});

  @override
  State<MemoryLine> createState() => _MemoryLineState();
}

class _MemoryLineState extends State<MemoryLine> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cache = PaintingBinding.instance.imageCache;
    return SelectableText(
      AppLocalizations.of(context).opMemImages(
        (cache.currentSizeBytes / 1048576).toStringAsFixed(1),
        cache.liveImageCount,
        cache.currentSize,
      ),
      key: const Key('op.memory'),
    );
  }
}
