import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

class HudBubble extends StatelessWidget {
  const HudBubble({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 220),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: Skin.shadow,
      border: Border.all(color: Skin.goldBottom, width: 2),
    ),
    child: Text(text, style: Skin.text(13)),
  );
}
