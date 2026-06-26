import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class CardivaBottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;
  // index → badge count; 0 hides the badge
  final Map<int, int> badges;

  const CardivaBottomNav({
    super.key,
    required this.activeIndex,
    required this.onTap,
    this.badges = const {},
  });

  static const _items = [
    _NavItem(Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
    _NavItem(Icons.favorite_rounded, Icons.favorite_border_rounded, 'Vitals'),
    _NavItem(Icons.monitor_heart_rounded, Icons.monitor_heart_outlined, 'AI Analysis'),
    _NavItem(Icons.chat_rounded, Icons.chat_bubble_outline_rounded, 'Chat'),
    _NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSm,
            blurRadius: 16,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_items.length, (i) {
          final active = i == activeIndex;
          final item = _items[i];
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        active ? item.filledIcon : item.outlinedIcon,
                        color: active
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 24,
                      ),
                      if ((badges[i] ?? 0) > 0)
                        Positioned(
                          top: -4,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (badges[i]! > 99)
                                  ? '99+'
                                  : '${badges[i]}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: AppTextStyles.caption.copyWith(
                      color: active
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData filledIcon;
  final IconData outlinedIcon;
  final String label;
  const _NavItem(this.filledIcon, this.outlinedIcon, this.label);
}
