import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification_model.dart';
import '../../providers/notifications_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

enum _Tab { all, alerts, health, system }

extension _TabExt on _Tab {
  String get label => switch (this) {
        _Tab.all => 'All',
        _Tab.alerts => 'Alerts',
        _Tab.health => 'Health',
        _Tab.system => 'System',
      };

  NotifType? get type => switch (this) {
        _Tab.all => null,
        _Tab.alerts => NotifType.alert,
        _Tab.health => NotifType.health,
        _Tab.system => NotifType.system,
      };
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _Tab _tab = _Tab.all;

  List<AppNotification> _filtered(List<AppNotification> all) {
    final type = _tab.type;
    if (type == null) return all;
    return all.where((n) => n.type == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    final filtered = _filtered(state.notifications);
    final activeType = _tab.type;
    final isMuted =
        activeType != null ? (state.muted[activeType] ?? false) : false;

    final sections = <String>[];
    for (final n in filtered) {
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
          // Per-category mute toggle — only shown when on a specific tab
          if (activeType != null)
            IconButton(
              tooltip:
                  isMuted ? 'Unmute ${_tab.label}' : 'Mute ${_tab.label}',
              icon: Icon(
                isMuted
                    ? Icons.notifications_off_rounded
                    : Icons.notifications_active_rounded,
                color: isMuted ? AppColors.textSecondary : AppColors.primary,
                size: 22,
              ),
              onPressed: () => notifier.toggleMuted(activeType),
            ),
          TextButton(
            onPressed: () => notifier.markAllRead(),
            child: Text(
              'Mark all read',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ───────────────────────────────────────────
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _Tab.values.map((t) {
                final active = t == _tab;
                final chipMuted =
                    t.type != null ? (state.muted[t.type!] ?? false) : false;
                return GestureDetector(
                  onTap: () => setState(() => _tab = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(
                        right: 8, top: 6, bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active
                            ? AppColors.primary
                            : AppColors.accentTint,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (chipMuted) ...[
                          Icon(
                            Icons.notifications_off_rounded,
                            size: 11,
                            color: active
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          t.label,
                          style: AppTextStyles.caption.copyWith(
                            color: active
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Muted banner ───────────────────────────────────────────
          if (isMuted)
            Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_off_rounded,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_tab.label} notifications are muted — new ones won\'t appear.',
                      style: AppTextStyles.caption
                          .copyWith(color: const Color(0xFF92400E)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => notifier.toggleMuted(activeType!),
                    child: Text(
                      'Unmute',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // ── Notification list ──────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_none_rounded,
                            size: 64, color: AppColors.accentTint),
                        const SizedBox(height: 12),
                        Text(
                          isMuted
                              ? 'Muted — no ${_tab.label.toLowerCase()} notifications'
                              : "You're all caught up",
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: sections.length,
                    itemBuilder: (_, si) {
                      final section = sections[si];
                      final items = filtered
                          .where((n) => n.section == section)
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Text(section,
                                style: AppTextStyles.caption),
                          ),
                          ...items.map(
                            (n) => Dismissible(
                              key: ValueKey(n.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) {
                                notifier.delete(n.id);
                                ScaffoldMessenger.of(context)
                                    .clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        const Text('Notification deleted'),
                                    duration: const Duration(seconds: 4),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () =>
                                          notifier.undoDelete(),
                                    ),
                                  ),
                                );
                              },
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.only(right: 22),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius:
                                      BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.delete_rounded,
                                        color: Colors.white, size: 22),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Delete',
                                      style: AppTextStyles.caption
                                          .copyWith(
                                              color: Colors.white,
                                              fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              child: _NotifCard(
                                notif: n,
                                onTap: () => notifier.markRead(n.id),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Notification card ──────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;

  const _NotifCard({
    required this.notif,
    required this.onTap,
  });

  Color get _stripeColor => switch (notif.type) {
        NotifType.alert => AppColors.danger,
        NotifType.health => AppColors.warning,
        NotifType.system => AppColors.primary,
      };

  IconData get _icon => switch (notif.type) {
        NotifType.alert => Icons.warning_rounded,
        NotifType.health => Icons.favorite_rounded,
        NotifType.system => Icons.settings_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final stripe = _stripeColor;
    return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: notif.isRead
                    ? AppColors.shadowLg
                    : AppColors.shadowSm,
                blurRadius: notif.isRead ? 6 : 12,
                offset: const Offset(0, 2),
              ),
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
                      Text(
                        notif.title,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: notif.isRead
                              ? FontWeight.w400
                              : FontWeight.w600,
                          color: notif.isRead
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(notif.subtitle, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(notif.time, style: AppTextStyles.caption),
                    if (!notif.isRead) ...[
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
        ),
    );
  }
}

