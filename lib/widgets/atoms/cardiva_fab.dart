import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CardivaFab extends StatelessWidget {
  final VoidCallback onTap;

  const CardivaFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLg,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.chat_bubble_outline_rounded,
            color: Colors.white, size: 24),
      ),
    );
  }
}
