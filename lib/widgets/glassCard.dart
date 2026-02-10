import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(32),
    this.radius = 32,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}