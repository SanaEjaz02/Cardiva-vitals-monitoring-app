import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum _NotifFilter { all, alerts, health, system }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotifFilter _filter = _NotifFilter.all;

  static const _notifs = [
    _Notif(
      section: 'Today',
      title: 'Fall Detected',
      subtitle: 'Auto-alert was sent to 2 contacts',
      time: '10:15 AM',
      type: _NotifType.alert,
      unread: true,
    ),
    _Notif(
      section: 'Today',
      title: 'SpO₂ Warning',
      subtitle: 'Dropped to 93% — 10:02 AM',
      time: '10:02 AM',
      type: _NotifType.health,
      unread: true,
    ),
    _Notif(
      section: 'Yesterday',
      title: 'Device Connected',
      subtitle: 'Cardiva Band 1 synced',
      time: '9:30 AM',
      type: _NotifType.system,
      unread: false,
    ),
    _Notif(
      section: 'Yesterday',
      title: 'Weekly Report Ready',
      subtitle: 'Apr 19–25 summary available',
      time: '8:00 AM',
      type: _NotifType.health,
      unread: false,
    ),
    _Notif(
      section: 'Earlier this week',
      title: 'Heart Rate Alert',
      subtitle: 'Resting HR above 100 bpm',
      time: 'Mon 2:10 PM',
      type: _NotifType.alert,
      unread: false,
    ),
  ];

  List<_Notif> get _filtered {
    if (_filter == _NotifFilter.all) return _notifs;
    return _notifs.where((n) {
      switch (_filter) {
        case _NotifFilter.alerts:
          return n.type == _NotifType.alert;
        case _NotifFilter.health:
          return n.type == _NotifType.health;
        case _NotifFilter.system:
          return n.type == _NotifType.system;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sections = <String>[];
    for (final n in _filtered) {
      if (!sections.contains(n.section)) sections.add(n.section);
    }

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Notifications', style: AppTextStyles.h1),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('Mark all read',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _NotifFilter.values.map((f) {
                final active = f == _filter;
                final label = switch (f) {
                  _NotifFilter.all => 'All',
                  _NotifFilter.alerts => 'Alerts',
                  _NotifFilter.health => 'Health',
                  _NotifFilter.system => 'System',
                };
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active ? AppColors.primary : AppColors.accentTint,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: AppTextStyles.caption.copyWith(
                          color: active ? Colors.white : AppColors.textSecondary,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_none_rounded,
                            size: 64, color: AppColors.accentTint),
                        const SizedBox(height: 12),
                        Text("You're all caught up",
                            style: AppTextStyles.caption),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sections.length,
                    itemBuilder: (_, si) {
                      final section = sections[si];
                      final items = _filtered
                          .where((n) => n.section == section)
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(section,
                                style: AppTextStyles.caption),
                          ),
                          ...items.map((n) => _NotifCard(notif: n)),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final _Notif notif;
  const _NotifCard({required this.notif});

  Color get _stripeColor {
    switch (notif.type) {
      case _NotifType.alert:
        return AppColors.danger;
      case _NotifType.health:
        return AppColors.warning;
      case _NotifType.system:
        return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (notif.type) {
      case _NotifType.alert:
        return Icons.warning_rounded;
      case _NotifType.health:
        return Icons.favorite_rounded;
      case _NotifType.system:
        return Icons.settings_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stripe = _stripeColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm, blurRadius: 12, offset: Offset(0, 2)),
        ],
        border: Border(left: BorderSide(color: stripe, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: stripe.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: stripe, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif.title,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(notif.subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(notif.time, style: AppTextStyles.caption),
                if (notif.unread) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _NotifType { alert, health, system }

class _Notif {
  final String section;
  final String title;
  final String subtitle;
  final String time;
  final _NotifType type;
  final bool unread;
  const _Notif({
    required this.section,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.type,
    required this.unread,
  });
}
