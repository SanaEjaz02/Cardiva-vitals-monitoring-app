import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/chat_message.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
// Queries chats the guardian participates in, then fetches emergency messages
// from each chat's subcollection using a single-field filter — no composite
// Firestore index required.

final _alertHistoryProvider =
    StreamProvider.autoDispose<List<ChatMessage>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: uid)
      .snapshots()
      .asyncMap((chatsSnap) async {
    final allAlerts = <ChatMessage>[];
    for (final chatDoc in chatsSnap.docs) {
      final msgsSnap = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatDoc.id)
          .collection('messages')
          .where('type', isEqualTo: 'emergency')
          .get();

      for (final doc in msgsSnap.docs) {
        final msg = ChatMessage.fromFirestore(doc);
        if (msg.receiverId == uid) allAlerts.add(msg);
      }
    }
    allAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allAlerts;
  });
});

// ── Tab ───────────────────────────────────────────────────────────────────────

class AttendantAlertHistoryTab extends ConsumerStatefulWidget {
  const AttendantAlertHistoryTab({super.key});

  @override
  ConsumerState<AttendantAlertHistoryTab> createState() =>
      _AttendantAlertHistoryTabState();
}

class _AttendantAlertHistoryTabState
    extends ConsumerState<AttendantAlertHistoryTab> {
  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(_alertHistoryProvider);

    // Fire a local notification the first time new alerts arrive.
    ref.listen<AsyncValue<List<ChatMessage>>>(_alertHistoryProvider,
        (previous, next) {
      if (previous == null) return;
      final prev = previous.valueOrNull?.length ?? 0;
      final curr = next.valueOrNull?.length ?? 0;
      if (curr > prev && mounted) {
        NotificationService.showEmergencyNotification(
          '🚨 Emergency Alert',
          'A patient has sent an emergency alert.',
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDeep],
            ),
            boxShadow: [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 3)),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.warning_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Alert History',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2)),
                    Text('Emergency alerts received',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.2)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.accentTint),
              const SizedBox(height: 12),
              Text('Could not load alerts',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.invalidate(_alertHistoryProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                        color: AppColors.primaryBg, shape: BoxShape.circle),
                    child: const Icon(Icons.notifications_off_rounded,
                        size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text('No emergency alerts yet',
                      style: AppTextStyles.h2
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                    'Emergency alerts sent by your patients\nwill appear here.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: alerts.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (_, i) => _AlertTile(alert: alerts[i]),
          );
        },
      ),
    );
  }
}

// ── Alert tile ────────────────────────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  final ChatMessage alert;
  const _AlertTile({required this.alert});

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final firstLine = alert.content.split('\n').first;

    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8E1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFE65100), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.senderName,
                          style: AppTextStyles.h2.copyWith(fontSize: 15),
                        ),
                      ),
                      Text(
                        _formatTime(alert.timestamp),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    firstLine,
                    style: AppTextStyles.body.copyWith(
                        color: const Color(0xFFE65100),
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
