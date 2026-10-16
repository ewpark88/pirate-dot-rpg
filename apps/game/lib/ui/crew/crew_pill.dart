import 'package:flutter/material.dart';

/// 작은 알약 (등급·출전 표시).
class CrewPill extends StatelessWidget {
  const CrewPill({required this.child, required this.fill, required this.border, super.key});

  final Widget child;
  final Color fill;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: border, width: 1.5),
    ),
    child: child,
  );
}
