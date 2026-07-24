import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_message.dart';
import '../../providers/user_provider.dart';
import '../../services/chat_service.dart';
import '../../services/link_service.dart';
import '../../services/local_chat_db.dart';
import '../../services/realtime_database_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

// Helpers shared by tiles
bool _isPending(Map<String, dynamic> g) => g['is_pending'] == true;

const _kHeaderColor = AppColors.primaryDeep;

// ── Providers ─────────────────────────────────────────────────────────────────

final _authUidProvider = StreamProvider.autoDispose<String>((ref) =>
    FirebaseAuth.instance.authStateChanges().map((u) => u?.uid ?? ''));

/// Listens to the patient document and builds the guardian list for chat.
/// Reads guardian_snapshot.linked_guardians (has UIDs once resolved) first;
/// falls back to manual_guardians so previously-added guardians always appear.
/// No cross-collection queries — everything is on the patient doc.
final _linkedGuardiansProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, patientUid) => patientUid.isEmpty
            ? Stream.value([])
            : LinkService.patientSnapshotStream(patientUid).map((data) {
                if (data == null) return [];

                // Primary: guardian_snapshot has pre-resolved UIDs
                final snap = data['guardian_snapshot'] as Map?;
                final snapList = snap?['linked_guardians'] as List?;
                if (snapList != null && snapList.isNotEmpty) {
                  return snapList.map((g) {
                    final m = Map<String, dynamic>.from(g as Map);
                    final uid = (m['uid'] as String? ?? '').trim();
                    final id = (m['id'] as String? ?? '');
                    final name = (m['name'] as String? ?? 'Guardian').trim();
                    final phone = (m['phone'] as String? ?? '').trim();
                    if (uid.isNotEmpty) {
                      return <String, dynamic>{'attendant_uid': uid, 'attendant_name': name};
                    }
                    return <String, dynamic>{
                      'attendant_uid': 'pending_$id',
                      'attendant_name': name,
                      'phone': phone,
                      'is_pending': true,
                    };
                  }).toList();
                }

                // Fallback: manual_guardians (always persisted, no UIDs yet)
                final manualList = List<Map<String, dynamic>>.from(
                    data['manual_guardians'] as List? ?? []);
                return manualList.map((mg) {
                  final id = (mg['id'] as String? ?? '');
                  final name = (mg['name'] as String? ?? 'Guardian').trim();
                  final phone = (mg['phone'] as String? ?? '').trim();
                  return <String, dynamic>{
                    'attendant_uid': 'pending_$id',
                    'attendant_name': name,
                    'phone': phone,
                    'is_pending': true,
                  };
                }).toList();
              }));

// Drives both sort order AND preloaded chat metadata (lastMessage, time, type)
// for every guardian tile — one stream instead of N per-tile streams.
final _chatListProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, uid) => ChatService.chatListStream(uid));

final _unreadProvider = StreamProvider.family<int, _CK>(
    (ref, k) => ChatService.unreadCountStream(k.patientUid, k.guardianUid));

// Warms the Firestore message cache for guardians that already have a chat doc.
// Only subscribed for existing chats — avoids permission-denied churn on new ones.
final _messagesProvider =
    StreamProvider.family<List<ChatMessage>, _CK>(
        (ref, k) => ChatService.messagesStream(k.patientUid, k.guardianUid));

class _CK {
  final String patientUid, guardianUid;
  const _CK(this.patientUid, this.guardianUid);
  @override
  bool operator ==(Object o) =>
      o is _CK && patientUid == o.patientUid && guardianUid == o.guardianUid;
  @override
  int get hashCode => Object.hash(patientUid, guardianUid);
}

// ── Chat List Screen ──────────────────────────────────────────────────────────

class PatientChatScreen extends ConsumerStatefulWidget {
  const PatientChatScreen({super.key});
  @override
  ConsumerState<PatientChatScreen> createState() => _PatientChatScreenState();
}

class _PatientChatScreenState extends ConsumerState<PatientChatScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  // Non-null once resolution runs. Overrides the Firestore stream so the
  // chat list never shows "pending" for a guardian who IS registered, even
  // when Firestore has no data yet.
  List<Map<String, dynamic>>? _resolvedLocally;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveGuardians());
  }

  /// Looks up a guardian's Firebase UID by querying Firestore guardians collection.
  /// Does NOT require RTDB — works on devices where WebSocket is blocked.
  Future<String?> _getGuardianUidByEmail(String email) async {
    if (email.isEmpty) return null;
    try {
      final db = FirebaseFirestore.instance;
      // Try flat email field (new saveProfile layout)
      var qs = await db
          .collection('guardians')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (qs.docs.isNotEmpty) return qs.docs.first.id;
      // Try nested profile.email (legacy layout)
      qs = await db
          .collection('guardians')
          .where('profile.email', isEqualTo: email)
          .limit(1)
          .get();
      if (qs.docs.isNotEmpty) return qs.docs.first.id;
    } catch (_) {}
    return null;
  }

  Future<void> _resolveGuardians() async {
    final myUid = ref.read(_authUidProvider).valueOrNull ?? '';
    if (myUid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Durable local record of every email -> uid we've EVER resolved, checked
      // before any network call. Without this, a guardian resolved while online
      // gets demoted back to "pending" (a dead-end tile with no chat access)
      // the instant a live re-resolution attempt fails while offline.
      final resolvedCacheKey = 'resolved_guardian_uids_${myUid}_v1';
      final resolvedCacheRaw = prefs.getString(resolvedCacheKey);
      final resolvedCache = <String, String>{
        if (resolvedCacheRaw != null)
          ...Map<String, dynamic>.from(jsonDecode(resolvedCacheRaw) as Map)
              .map((k, v) => MapEntry(k, v as String)),
      };
      var resolvedCacheDirty = false;

      // 0. RTDB resolved_guardians — fastest path, written when guardian logs in.
      //    This works even when Firestore WebSocket is unavailable.
      final rtdbResolved =
          await RealtimeDatabaseService.watchResolvedGuardians(myUid).first
              .timeout(const Duration(seconds: 5), onTimeout: () => {});
      if (rtdbResolved.isNotEmpty) {
        final fromRtdb = rtdbResolved.entries.map((e) {
          final g = e.value;
          final email = (g['email'] as String? ?? '').trim().toLowerCase();
          if (email.isNotEmpty && resolvedCache[email] != e.key) {
            resolvedCache[email] = e.key;
            resolvedCacheDirty = true;
          }
          return <String, dynamic>{
            'attendant_uid': e.key,
            'attendant_name': g['name'] as String? ?? 'Guardian',
          };
        }).toList();
        if (!mounted) return;
        setState(() => _resolvedLocally = fromRtdb);
      }

      // 1. Manual guardians from SharedPreferences (always available, no network).
      List<dynamic>? rawList;
      final cached = prefs.getString('manual_guardians_${myUid}_v1');
      if (cached != null) rawList = jsonDecode(cached) as List;

      // Fallback: Firestore (only if SharedPreferences is empty).
      if (rawList == null || rawList.isEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('patients')
              .doc(myUid)
              .get();
          rawList = snap.data()?['manual_guardians'] as List?;
        } catch (_) {}
      }
      if (rawList == null || rawList.isEmpty) {
        if (resolvedCacheDirty) {
          await prefs.setString(resolvedCacheKey, jsonEncode(resolvedCache));
        }
        return;
      }

      // 2. Resolve UIDs — prefer the durable local cache first, only hitting
      //    the network for guardians that have never been resolved before.
      final resolved = <Map<String, dynamic>>[];
      final fsGuardians = <Map<String, dynamic>>[]; // for Firestore snapshot

      for (final g in rawList) {
        final m = Map<String, dynamic>.from(g as Map);
        final email = (m['email'] ?? '').toString().trim().toLowerCase();
        final name  = (m['name']  ?? 'Guardian').toString();
        final phone = (m['phone'] ?? '').toString();
        final id    = (m['id']    ?? '').toString();

        String uid = email.isNotEmpty ? (resolvedCache[email] ?? '') : '';

        if (uid.isEmpty && email.isNotEmpty) {
          // Primary: Firestore query (works without RTDB WebSocket).
          uid = await _getGuardianUidByEmail(email) ?? '';
          // Fallback: RTDB email_index (works when RTDB is available).
          if (uid.isEmpty) {
            uid = await RealtimeDatabaseService.getUidByEmail(email) ?? '';
          }
          if (uid.isNotEmpty) {
            resolvedCache[email] = uid;
            resolvedCacheDirty = true;
          }
        }

        if (uid.isNotEmpty) {
          resolved.add(<String, dynamic>{
            'attendant_uid':  uid,
            'attendant_name': name,
          });
          // Persist so the stream catches it even before Firestore is fixed.
          RealtimeDatabaseService.saveResolvedGuardian(
            patientUid:  myUid,
            guardianUid: uid,
            name:  name,
            email: email,
            phone: phone,
          ).catchError((_) {});
        } else {
          resolved.add(<String, dynamic>{
            'attendant_uid':  'pending_$id',
            'attendant_name': name,
            'phone': phone,
            'email': email,
            'is_pending': true,
          });
        }
        fsGuardians.add(<String, dynamic>{
          'id': id, 'name': name, 'email': email, 'phone': phone, 'uid': uid,
        });
      }

      if (resolvedCacheDirty) {
        await prefs.setString(resolvedCacheKey, jsonEncode(resolvedCache));
      }

      if (!mounted) return;
      setState(() => _resolvedLocally = resolved);

      // 3. Best-effort Firestore guardian_snapshot write (fixes things once
      //    Firestore rules are deployed — no-op if rules aren't deployed yet).
      final patientName = ref.read(userProvider)?.name ?? '';
      LinkService.saveGuardiansSnapshot(
        patientUid:  myUid,
        guardians:   fsGuardians,
        patientName: patientName,
      ).catchError((_) {});
    } catch (e) {
      debugPrint('[ChatScreen] _resolveGuardians error: $e');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(_authUidProvider).valueOrNull ?? '';
    final linkedAsync = ref.watch(_linkedGuardiansProvider(myUid));
    // Use locally-resolved list (RTDB-based, works without Firestore) when
    // available. Falls back to the Firestore stream while resolution runs.
    final linked = _resolvedLocally ?? linkedAsync.valueOrNull ?? [];

    // Single stream drives both sort order AND per-tile chat metadata.
    // Keyed by guardianId so each tile reads its own lastMessage/time/type
    // without opening its own Firestore stream.
    final chatList = ref.watch(_chatListProvider(myUid)).valueOrNull ?? [];
    final chatDataMap = <String, Map<String, dynamic>>{};
    final chatOrder = <String, int>{};
    for (int i = 0; i < chatList.length; i++) {
      final gId = chatList[i]['guardianId'] as String? ?? '';
      chatOrder[gId] = i;
      chatDataMap[gId] = chatList[i];
    }
    // Warm Firestore cache for guardians with existing chats so opening them is instant.
    if (myUid.isNotEmpty) {
      for (final g in linked) {
        final gUid = g['attendant_uid'] as String? ?? '';
        if (gUid.isNotEmpty && chatDataMap.containsKey(gUid)) {
          ref.watch(_messagesProvider(_CK(myUid, gUid)));
        }
      }
    }

    final sorted = [...linked]..sort((a, b) {
        final ai = chatOrder[a['attendant_uid'] as String? ?? ''] ?? 999;
        final bi = chatOrder[b['attendant_uid'] as String? ?? ''] ?? 999;
        return ai.compareTo(bi);
      });

    final sq = _search.toLowerCase();
    final filtered = sq.isEmpty
        ? sorted
        : sorted
            .where((g) => (g['attendant_name'] as String? ?? '')
                .toLowerCase()
                .contains(sq))
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 58),
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
                  child: const Icon(Icons.people_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Guardians',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2)),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          linked.isEmpty
                              ? 'No guardians linked'
                              : '${linked.length} guardian${linked.length == 1 ? '' : 's'} linked',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.8),
                              height: 1.2),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(58),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search guardians…',
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
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Cardiva AI tile — always pinned at top regardless of guardian count
          const _CardivaAiTile(),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: linkedAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : linked.isEmpty
                    ? _EmptyState(myUid: myUid)
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_off_rounded,
                                    size: 48, color: AppColors.accentTint),
                                const SizedBox(height: 12),
                                Text('No results for "$_search"',
                                    style: AppTextStyles.body.copyWith(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, indent: 72, color: AppColors.divider),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final g = filtered[i];
                              final guardianUid =
                                  g['attendant_uid'] as String? ?? '';
                              final guardianName =
                                  g['attendant_name'] as String? ?? 'Guardian';

                              if (_isPending(g)) {
                                return _PendingGuardianTile(
                                  name: guardianName,
                                  phone: g['phone'] as String? ?? '',
                                );
                              }

                              return _GuardianTile(
                                myUid: myUid,
                                guardianUid: guardianUid,
                                guardianName: guardianName,
                                chatData: chatDataMap[guardianUid],
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String myUid;
  const _EmptyState({required this.myUid});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    color: AppColors.primaryBg, shape: BoxShape.circle),
                child: const Icon(Icons.people_outline_rounded,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text('No guardians yet',
                  style:
                      AppTextStyles.h2.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(
                'Add a guardian in Settings → Guardians.\nThey will appear here once registered.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

// ── Pending guardian tile (registered in manual_guardians but no account yet) ─

class _PendingGuardianTile extends StatelessWidget {
  final String name;
  final String phone;
  const _PendingGuardianTile({required this.name, required this.phone});

  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.bgLight,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'G',
                      style: AppTextStyles.h2.copyWith(
                          color: AppColors.textSecondary, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.h2),
                      if (phone.isNotEmpty)
                        Text(phone, style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This guardian hasn\'t registered on Cardiva yet. '
                        'Ask them to download the app and register with this contact info.',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => _showInfo(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.bgLight,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'G',
          style: AppTextStyles.h2.copyWith(
              color: AppColors.textSecondary, fontSize: 18),
        ),
      ),
      title: Text(name, style: AppTextStyles.h2),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(phone.isNotEmpty ? phone : 'No phone',
              style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Pending — tap for info',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Guardian tile ─────────────────────────────────────────────────────────────

class _GuardianTile extends ConsumerWidget {
  final String myUid, guardianUid, guardianName;
  // Pre-loaded from the parent's _chatListProvider stream — no extra reads.
  final Map<String, dynamic>? chatData;
  const _GuardianTile({
    required this.myUid,
    required this.guardianUid,
    required this.guardianName,
    this.chatData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread =
        ref.watch(_unreadProvider(_CK(myUid, guardianUid))).valueOrNull ?? 0;

    final lastMsg = chatData?['lastMessage'] as String? ?? '';
    final lastType = chatData?['lastType'] as String? ?? 'text';
    final ts = (chatData?['lastMessageTime'] as Timestamp?)?.toDate();
    final timeStr = ts == null ? '' : _fmt(ts);

    // Emergency alerts show the same preview as regular messages — no special label.
    final preview = lastType == 'report'
        ? '📋 Health Report'
        : lastMsg.isEmpty
            ? 'Tap to start chatting'
            : lastMsg;
    final previewColor =
        lastMsg.isEmpty ? AppColors.accentTint : AppColors.textSecondary;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.primaryBg,
        child: Text(
          guardianName.isNotEmpty ? guardianName[0].toUpperCase() : 'G',
          style: AppTextStyles.h2.copyWith(color: _kHeaderColor, fontSize: 18),
        ),
      ),
      title: Text(
        guardianName,
        style: AppTextStyles.h2.copyWith(
          fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          color: unread > 0 ? AppColors.textPrimary : previewColor,
          fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
          fontStyle: lastMsg.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      trailing: _Trailing(unread: unread, timeStr: timeStr),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientGuardianChatPage(
            myUid: myUid,
            guardianUid: guardianUid,
            guardianName: guardianName,
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inDays == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    if (d.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[t.weekday - 1];
    }
    return '${t.day}/${t.month}';
  }
}

// ── Cardiva AI tile (always first in the list) ────────────────────────────────

class _CardivaAiTile extends StatelessWidget {
  const _CardivaAiTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.favorite_rounded,
            color: Colors.white, size: 24),
      ),
      title: const Text('Cardiva AI',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: Text('Your personal health assistant',
          style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('AI',
            style: AppTextStyles.caption.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w700)),
      ),
      onTap: () => Navigator.pushNamed(context, '/chat'),
    );
  }
}

// ── Trailing (unread badge + time) ────────────────────────────────────────────

class _Trailing extends StatelessWidget {
  final int unread;
  final String timeStr;
  const _Trailing({required this.unread, required this.timeStr});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timeStr.isNotEmpty)
            Text(
              timeStr,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: unread > 0 ? _kHeaderColor : AppColors.textSecondary,
                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          const SizedBox(height: 4),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _kHeaderColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ],
      );
}

// ── Individual chat page ──────────────────────────────────────────────────────

class PatientGuardianChatPage extends ConsumerStatefulWidget {
  final String myUid, guardianUid, guardianName;
  const PatientGuardianChatPage({
    super.key,
    required this.myUid,
    required this.guardianUid,
    required this.guardianName,
  });

  @override
  ConsumerState<PatientGuardianChatPage> createState() =>
      _PatientGuardianChatPageState();
}

class _PatientGuardianChatPageState
    extends ConsumerState<PatientGuardianChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  StreamSubscription<List<ChatMessage>>? _msgSub;
  Timer? _refreshTimer;
  List<ChatMessage> _messages = [];
  bool _msgLoading = true;
  bool _msgError = false;

  final _hiddenIds = <String>{};
  final _selectedIds = <String>{};
  bool get _inSelectionMode => _selectedIds.isNotEmpty;

  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectSub;

  String get _chatId =>
      ChatService.chatId(widget.myUid, widget.guardianUid);

  void _toggleSelect(String id) => setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      });

  Future<void> _deleteSelected() async {
    final toDelete = _selectedIds.toList();
    setState(() {
      _selectedIds.clear();
      _hiddenIds.addAll(toDelete);
      _messages = _messages.where((m) => !toDelete.contains(m.id)).toList();
    });
    for (final id in toDelete) {
      LocalChatDb.instance.deleteMessage(_chatId, id).catchError((_) {});
      ChatService.deleteMessage(widget.myUid, widget.guardianUid, id)
          .catchError((_) {});
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFromLocal();
    _subscribeMessages();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshFromServer(),
    );
    ChatService.markRead(widget.myUid, widget.guardianUid).catchError((_) {});
    _connectSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!mounted) return;
      final wasOffline = !_isOnline;
      setState(() => _isOnline = online);
      if (online && wasOffline) {
        _refreshFromServer();
        _subscribeMessages();
      }
    });
  }

  Future<void> _loadFromLocal() async {
    final cached = await LocalChatDb.instance.loadMessages(_chatId);
    if (!mounted || cached.isEmpty) return;
    setState(() {
      _messages = cached;
      _msgLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _refreshFromServer() async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get(const GetOptions(source: Source.server));
    } catch (_) {}
  }

  void _subscribeMessages() {
    _msgSub?.cancel();
    _msgSub = ChatService.messagesStream(widget.myUid, widget.guardianUid)
        .listen(
          (msgs) {
            if (!mounted) return;
            LocalChatDb.instance.saveMessages(_chatId, msgs).catchError((_) {});
            final filtered = _hiddenIds.isEmpty
                ? msgs
                : msgs.where((m) => !_hiddenIds.contains(m.id)).toList();
            setState(() { _messages = filtered; _msgLoading = false; _msgError = false; });
            if (msgs.isNotEmpty) _scrollToBottom();
            ChatService.markRead(widget.myUid, widget.guardianUid).catchError((_) {});
          },
          onError: (_) {
            if (mounted) setState(() { _msgLoading = false; _msgError = true; });
          },
        );
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _refreshTimer?.cancel();
    _connectSub?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _myName => ref.read(userProvider)?.name ?? 'Patient';

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    final wasError = _msgError;

    // Show the message in the UI immediately — don't wait for Firestore.
    final now = DateTime.now();
    final tempMsg = ChatMessage(
      id: 'temp_${now.millisecondsSinceEpoch}',
      senderId: widget.myUid,
      receiverId: widget.guardianUid,
      senderName: _myName,
      content: text,
      timestamp: now,
    );
    setState(() {
      _messages = [..._messages, tempMsg];
      _msgLoading = false;
      _msgError = false;
    });
    _scrollToBottom();

    // Fire-and-forget — the message is already visible. UI never spins.
    ChatService.sendMessage(
      patientUid: widget.myUid,
      guardianUid: widget.guardianUid,
      senderUid: widget.myUid,
      senderName: _myName,
      text: text,
    ).then((_) {
      // For a brand-new chat the subscription was denied before the doc
      // existed — restart it now that the doc has been created.
      if (wasError && mounted) _subscribeMessages();
    }).catchError((_) {
      if (mounted) {
        setState(() => _messages =
            _messages.where((m) => m.id != tempMsg.id).toList());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send — please retry')));
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  Widget _buildMessageArea() {
    if (_msgLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_msgError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.accentTint),
            const SizedBox(height: 12),
            Text('Could not load messages',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _subscribeMessages,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 56, color: AppColors.accentTint),
            const SizedBox(height: 12),
            Text('Say hi to ${widget.guardianName}!',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _Bubble(
        msg: _messages[i],
        myUid: widget.myUid,
        guardianUid: widget.guardianUid,
        isSelected: _selectedIds.contains(_messages[i].id),
        isSelectionMode: _inSelectionMode,
        onSelectMessage: _toggleSelect,
        onDelete: (id) {
          setState(() {
            _hiddenIds.add(id);
            _messages = _messages.where((m) => m.id != id).toList();
          });
          LocalChatDb.instance.deleteMessage(_chatId, id).catchError((_) {});
          ChatService.deleteMessage(widget.myUid, widget.guardianUid, id)
              .catchError((_) {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: _inSelectionMode
          ? AppBar(
              backgroundColor: AppColors.primaryDeep,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _selectedIds.clear()),
              ),
              title: Text(
                '${_selectedIds.length} selected',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_rounded),
                  tooltip: 'Delete selected',
                  onPressed: _deleteSelected,
                ),
              ],
            )
          : PreferredSize(
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
                  foregroundColor: Colors.white,
                  title: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          widget.guardianName.isNotEmpty
                              ? widget.guardianName[0].toUpperCase()
                              : 'G',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.guardianName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: Column(
        children: [
          if (!_isOnline)
            Container(
              width: double.infinity,
              color: const Color(0xFFF59E0B),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'You\'re offline — showing cached messages',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildMessageArea()),
          _InputBar(
            ctrl: _ctrl,
            onSend: _send,
            hintText: 'Message ${widget.guardianName}…',
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final String myUid;
  final String guardianUid;
  final bool isSelected;
  final bool isSelectionMode;
  final void Function(String id)? onSelectMessage;
  final void Function(String id)? onDelete;

  const _Bubble({
    required this.msg,
    required this.myUid,
    required this.guardianUid,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onSelectMessage,
    this.onDelete,
  });

  bool get _isMe => msg.senderId == myUid;

  Color _bg() {
    if (msg.type == MessageType.report) return AppColors.primaryBg;
    return _isMe ? _kHeaderColor : Colors.white;
  }

  Color _fg() {
    if (msg.type == MessageType.report) return AppColors.primaryDeep;
    return _isMe ? Colors.white : AppColors.textPrimary;
  }

  String? _extractMapsUrl() {
    final match =
        RegExp(r'https://maps\.google\.com/\?q=[^\s]+').firstMatch(msg.content);
    return match?.group(0);
  }

  void _showMenu(BuildContext context) {
    final mapsUrl = _extractMapsUrl();
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.primary),
              title: const Text('Select'),
              onTap: () {
                Navigator.pop(context);
                onSelectMessage?.call(msg.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: msg.content));
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 2)),
                );
              },
            ),
            if (mapsUrl != null)
              ListTile(
                leading: const Icon(Icons.location_on_rounded,
                    color: AppColors.primary),
                title: const Text('Open Location'),
                onTap: () {
                  Navigator.pop(context);
                  launchUrl(Uri.parse(mapsUrl),
                      mode: LaunchMode.externalApplication);
                },
              ),
            if (_isMe)
              ListTile(
                leading:
                    const Icon(Icons.delete_rounded, color: AppColors.danger),
                title: const Text('Delete Message',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete?.call(msg.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  // Renders the message body. If a Google Maps URL is found it is replaced by
  // an inline tappable location card; the rest of the text is shown above it.
  Widget _buildText() {
    final mapsUrl = _extractMapsUrl();
    if (mapsUrl == null) {
      return Text(msg.content,
          style: TextStyle(fontSize: 14, color: _fg(), height: 1.4));
    }

    // Strip the maps URL (and the preceding "📍 ") from the body text.
    final bodyText = msg.content
        .replaceFirst(RegExp(r'📍\s*https://maps\.google\.com/\?q=[^\s]+'), '')
        .trimRight();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bodyText.isNotEmpty) ...[
          Text(bodyText,
              style: TextStyle(fontSize: 14, color: _fg(), height: 1.4)),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: () => launchUrl(Uri.parse(mapsUrl),
              mode: LaunchMode.externalApplication),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _isMe ? 0.18 : 0.0),
              border: Border.all(color: _fg().withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_rounded,
                    size: 16, color: _isMe ? Colors.white : AppColors.primary),
                const SizedBox(width: 6),
                Text('Open Location',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isMe ? Colors.white : AppColors.primary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final time =
        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    final bubble = GestureDetector(
      onTap: isSelectionMode ? () => onSelectMessage?.call(msg.id) : null,
      onLongPress: () {
        if (isSelectionMode) {
          onSelectMessage?.call(msg.id);
        } else {
          _showMenu(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? _bg().withValues(alpha: 0.6)
              : _bg(),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft:
                _isMe ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight:
                _isMe ? const Radius.circular(4) : const Radius.circular(18),
          ),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadowLg, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.type == MessageType.report)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_rounded, size: 13, color: _fg()),
                    const SizedBox(width: 4),
                    Text('Health Report',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _fg())),
                  ],
                ),
              ),
            _buildText(),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time,
                    style: TextStyle(
                        fontSize: 10, color: _fg().withValues(alpha: 0.65))),
                if (_isMe) ...[
                  const SizedBox(width: 3),
                  _TickIcon(
                    isSent: !msg.id.startsWith('temp_'),
                    isRead: msg.isRead,
                    color: _fg(),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    // In selection mode wrap with a row that shows the checkmark circle.
    if (isSelectionMode) {
      final check = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.accentTint,
            width: 2,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
            : null,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment:
              _isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: _isMe
              ? [bubble, const SizedBox(width: 8), check]
              : [check, const SizedBox(width: 8), bubble],
        ),
      );
    }

    return Align(
      alignment: _isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final String hintText;
  const _InputBar({
    required this.ctrl,
    required this.onSend,
    this.hintText = 'Message…',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle:
                    AppTextStyles.body.copyWith(color: AppColors.accentTint),
                filled: true,
                fillColor: const Color(0xFFF0F4F8),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: _kHeaderColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickIcon extends StatelessWidget {
  final bool isSent;
  final bool isRead;
  final Color color;
  const _TickIcon({required this.isSent, required this.isRead, required this.color});

  @override
  Widget build(BuildContext context) {
    if (!isSent) {
      return Icon(Icons.access_time_rounded, size: 11, color: color.withValues(alpha: 0.6));
    }
    return Icon(
      Icons.done_all_rounded,
      size: 14,
      color: isRead ? AppColors.primary : color.withValues(alpha: 0.6),
    );
  }
}
