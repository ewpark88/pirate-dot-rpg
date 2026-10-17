import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:intl/intl.dart';
import 'package:pirate_dot/adapters/save_transfer.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 설정 '세이브 옮기기' (S1·S5 2026-10-18, 어댑터 SaveTransfer · saveImportProvider): 설명 한 줄 · [코드 복사](클립보드) ·
/// [코드 붙여 넣기] → 붙여 넣기 창 → 지금 vs 가져올 진행(최고 스테이지·선원 수·저장 시각) → [덮어쓰기] → 한 번 더 확인 → 토스트.
/// 깨진 코드는 '코드가 맞지 않아요'. 가져오기가 없는 빌드(saveImportProvider null)면 칸째 숨긴다.
class SaveTransferSection extends ConsumerWidget {
  const SaveTransferSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.uiSaveHelp, style: Skin.text(14, color: Skin.sub)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SkinButton(
                  key: const Key('save.copy'),
                  tone: SkinTone.plain,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: SaveTransfer.export(ref.read(gameStateProvider))));
                    if (context.mounted) showSkinToast(context, l10n.uiSaveCopied);
                  },
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.uiSaveCopy)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SkinButton(
                  key: const Key('save.paste'),
                  onPressed: () => unawaited(
                    showSkinDialog<void>(context, builder: (_) => const SaveImportDialog()),
                  ),
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.uiSavePaste)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 붙여 넣기 창: 글 칸 + [클립보드에서] + [확인] → 읽히면 비교 + [덮어쓰기].
class SaveImportDialog extends ConsumerStatefulWidget {
  const SaveImportDialog({super.key});

  @override
  ConsumerState<SaveImportDialog> createState() => _SaveImportDialogState();
}

class _SaveImportDialogState extends ConsumerState<SaveImportDialog> {
  final _text = TextEditingController();
  GameState? _incoming;
  bool _bad = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _check() {
    try {
      final s = SaveTransfer.import(_text.text);
      setState(() {
        _incoming = s;
        _bad = false;
      });
    } on SaveCorruptException {
      setState(() {
        _incoming = null;
        _bad = true;
      });
    }
  }

  Future<void> _overwrite() async {
    final l10n = AppLocalizations.of(context);
    final incoming = _incoming!;
    final sure = await showSkinDialog<bool>(
      context,
      builder: (ctx) => PixelDialog(
        key: const Key('save.sure'),
        title: l10n.uiSaveOverwrite,
        content: Text(l10n.uiSaveSure, textAlign: TextAlign.center, style: Skin.text(16)),
        actions: [
          SkinButton(
            key: const Key('save.sure.no'),
            tone: SkinTone.plain,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.uiCancel),
          ),
          SkinButton(
            key: const Key('save.sure.yes'),
            tone: SkinTone.gold,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.uiSaveSureYes),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await ref.read(saveImportProvider)?.call(incoming);
    if (!mounted) return;
    Navigator.of(context).pop();
    showSkinToast(context, l10n.uiSaveDone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(gameStateProvider);
    final incoming = _incoming;
    return PixelDialog(
      key: const Key('save.import'),
      title: l10n.uiSavePaste,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('save.text'),
            controller: _text,
            maxLines: 3,
            style: Skin.text(12),
            decoration: InputDecoration(
              hintText: l10n.uiSavePasteHint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (_) => setState(() => _incoming = null),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('save.clip'),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) setState(() => _text.text = data!.text!);
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l10n.uiSaveFromClipboard, style: Skin.text(14, color: Skin.sub)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SkinButton(
                  key: const Key('save.check'),
                  tone: SkinTone.plain,
                  height: 44,
                  onPressed: _check,
                  child: Text(l10n.uiSaveCheck),
                ),
              ),
            ],
          ),
          if (_bad)
            Text(
              l10n.uiSaveBad,
              key: const Key('save.bad'),
              style: Skin.text(14, color: Skin.danger),
            ),
          if (incoming != null) ...[
            const SizedBox(height: 6),
            Text(l10n.uiSaveCompare, style: Skin.bold(14)),
            Text(
              l10n.uiSaveStage(now.progress.bestStage, incoming.progress.bestStage),
              key: const Key('save.stage'),
              style: Skin.text(14),
            ),
            Text(l10n.uiSaveCrews(now.crews.length, incoming.crews.length), style: Skin.text(14)),
            Text(
              l10n.uiSaveSavedAt(DateFormat.yMd(l10n.localeName).add_Hm().format(incoming.savedAt.toLocal())),
              style: Skin.text(13, color: Skin.sub),
            ),
            const SizedBox(height: 8),
            SkinButton(
              key: const Key('save.overwrite'),
              tone: SkinTone.gold,
              onPressed: () => unawaited(_overwrite()),
              child: Text(l10n.uiSaveOverwrite),
            ),
          ],
        ],
      ),
    );
  }
}
