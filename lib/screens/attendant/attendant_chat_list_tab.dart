import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/link_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'attendant_patient_chat_screen.dart';
import 'scan_qr_screen.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _linkedPatientsForChatProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, uid) => LinkService.linkedPatientsStream(uid));

final _chatDocForGuardianProvider =
    StreamProvider.family<Map<String, dynamic>?, _ChatKey>((ref, key) {
  final cid = ChatService.chatId(key.myUid, key.otherUid);
  return FirebaseFirestore.instance
      .collection('chats')
      .doc(cid)
      .snapshots()
      .map((s) => s.exists ? s.data() : null);
});

final _unreadForGuardianProvider = StreamProvider.family<int, _ChatKey>(
    (ref, key) => ChatService.unreadCountStream(key.myUid, key.otherUid));

class _ChatKey {
  final String myUid, otherUid;
  const _ChatKey(this.myUid, this.otherUid);
  @override
  bool operator ==(Object o) =>
      o is _ChatKey && myUid == o.myUid && otherUid == o.otherUid;
  @override
  int get hashCode => Object.hash(myUid, otherUid);
}

// ── Chat List Tab (WhatsApp-style) ────────────────────────────────────────────

class AttendantChatListTab extends ConsumerStatefulWidget {
  const AttendantChatListTab({super.key});

  @override
  ConsumerState<AttendantChatListTab> createState() =>
      _AttendantChatListTabState();
}

class _AttendantChatListTabState extends ConsumerState<AttendantChatListTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.currentUser?.uid ?? '';
    final patientsAsync = ref.watch(_linkedPatientsForChatProvider(myUid));

    return Column(
      children: [
        // ── WhatsApp-style header ──────────────────────────────────────────
        Container(
          color: AppColors.primaryDeep,
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medical_services_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cardiva',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2),
                      ),
                      Text(
                        'Messages',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.2),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Scan QR shortcut
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ScanQrScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Scan QR',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Search bar ───────────────────────────────────────────────
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search patients…',
                  hintStyle: AppTextStyles.body
                      .copyWith(color: AppColors.accentTint, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.accentTint, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.accentTint, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // ── Patient list ───────────────────────────────────────────────────
        Expanded(
          child: patientsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.accentTint, size: 48),
                    const SizedBox(height: 12),
                    Text('Could not load messages',
                        style: AppTextStyles.h2
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            data: (patients) {
              final filtered = _search.isEmpty
                  ? patients
                  : patients.where((p) {
                      final name =
                          (p['patient_name'] as String? ?? '').toLowerCase();
                      return name.contains(_search);
                    }).toList();

              if (patients.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                              color: AppColors.primaryBg,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.people_outline_rounded,
                              size: 40, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        Text('No conversations yet',
                            style: AppTextStyles.h2
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Text(
                          'Scan a patient\'s QR code to link and start messaging.',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ScanQrScreen()),
                          ),
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Scan Patient QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off_rounded,
                          size: 48, color: AppColors.accentTint),
                      const SizedBox(height: 12),
                      Text(
                        'No results for "$_search"',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, indent: 72, color: AppColors.divider),
                itemBuilder: (ctx, i) {
                  final p = filtered[i];
                  final patientUid = p['patient_uid'] as String;
                  final patientName =
                      p['patient_name'] as String? ?? 'Patient';
                  return _PatientChatTile(
                    myUid: myUid,
                    patientUid: patientUid,
                    patientName: patientName,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Per-patient chat tile ─────────────────────────────────────────────────────

class _PatientChatTile extends ConsumerWidget {
  final String myUid, patientUid, patientName;
  const _PatientChatTile({
    required this.myUid,
    required this.patientUid,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(
        _chatDocForGuardianProvider(_ChatKey(myUid, patientUid)));
    final unreadAsync = ref.watch(
        _unreadForGuardianProvider(_ChatKey(myUid, patientUid)));

    final chatData = chatAsync.valueOrNull;
    final lastMsg = chatData?['lastMessage'] as String? ?? '';
    final lastType = chatData?['lastType'] as String? ?? 'text';
    final ts = (chatData?['lastMessageTime'] as Timestamp?)?.toDate();
    final timeStr = ts == null ? '' : _fmtTime(ts);
    final unread = unreadAsync.valueOrNull ?? 0;

    final preview = switch (lastType) {
      'emergency' => '🚨 Emergency Alert',
      'report' => '📋 Health Report',
      _ => lastMsg.isEmpty ? 'Tap to start chatting' : lastMsg,
    };
    final previewColor = switch (lastType) {
      'emergency' => AppColors.danger,
      _ => lastMsg.isEmpty ? AppColors.accentTint : AppColors.textSecondary,
    };

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.primaryBg,
        child: Text(
          patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
          style: AppTextStyles.h2
              .copyWith(color: AppColors.primary, fontSize: 18),
        ),
      ),
      title: Text(patientName, style: AppTextStyles.h2),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          color: previewColor,
          fontStyle:
              lastMsg.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timeStr.isNotEmpty)
            Text(
              timeStr,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: unread > 0
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight:
                    unread > 0 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          const SizedBox(height: 4),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            )
          else if (lastType == 'emergency')
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.danger, shape: BoxShape.circle),
            ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttendantPatientChatScreen(
            patientUid: patientUid,
            patientName: patientName,
          ),
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inDays == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[t.weekday - 1];
    }
    return '${t.day}/${t.month}';
  }
}
