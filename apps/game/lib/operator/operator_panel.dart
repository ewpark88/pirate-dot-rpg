import 'package:flutter/material.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';

/// 운영자 패널 자리. UI 레인(S4)이 선원·비교·전장·타격감·경제·광고·언어·저장 묶음을 채운다.
/// 패널의 모든 조작은 OperatorCommand만 보낸다.
class OperatorPanel extends StatelessWidget {
  const OperatorPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(appBar: AppBar(title: Text(l10n.opPanelTitle)));
  }
}
