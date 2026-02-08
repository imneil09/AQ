import 'dart:ui';
import 'package:flutter/material.dart';

class BackgroundBlur extends StatelessWidget {
  final Color color;
  final double size;
  final double top;
  final double right;
  final double bottom;
  final double left;

  const BackgroundBlur({
    super.key,
    required this.color,
    required this.size,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.left = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Only position if values are provided (simple logic)
    return Positioned(
      top: top != 0 ? top : null,
      right: right != 0 ? right : null,
      bottom: bottom != 0 ? bottom : null,
      left: left != 0 ? left : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }
}