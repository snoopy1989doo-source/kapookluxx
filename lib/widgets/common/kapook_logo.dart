import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_design.dart';

class KapookLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const KapookLogo({
    super.key,
    this.size = 92,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow:
            showShadow ? AppElevation.soft(AppColors.brandStart) : const [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.20),
        child: Image.asset(
          'assets/branding/kapook_logo.png',
          fit: BoxFit.cover,
          semanticLabel: 'โลโก้ Kapookluxx',
        ),
      ),
    );
  }
}
