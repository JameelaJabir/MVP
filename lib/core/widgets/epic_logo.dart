import 'package:flutter/material.dart';
import '../app_colors.dart';
class EpicLogo extends StatelessWidget {
  final Color color;
  final double fontSize;
  final double? width;
  const EpicLogo({
    super.key,
    this.color = AppColors.primary,
    this.fontSize = 40,
    this.width,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Image.asset(
      'assets/images/Logo.png',
      width: width ?? 90,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, _, _) => Text(
        'epic.',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: -1.5,
        ),
      ),
      ),
    );
  }
}
