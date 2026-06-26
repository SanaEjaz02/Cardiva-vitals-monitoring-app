import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_message.dart';
import '../../providers/user_provider.dart';
import '../../services/chat_service.dart';
import '../../services/link_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

// ── Header color ───────────────────────────────────────────────────────────────
const _kHeaderColor = AppColors.primaryDeep;

// ── Providers ─────────────────────────────────────────────────────────────────

final _authUidProvider = StreamProvider.autoDispose<String>((ref) =>
    FirebaseAuth.instance.authStateChanges().map((u) => u?.uid ?? ''));

final _linkedGuardiansProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, uid) => LinkService.linkedGuardiansStream(uid));

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(_authUidProvider).valueOrNull ?? '';
    final linkedAsync = ref.watch(_linkedGuardiansProvider(myUid));
    final linked = linkedAsync.valueOrNull ?? [];

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
      body: linkedAsync.isLoading
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
                      // +1 for the pinned Cardiva AI tile at the top
                      itemCount: filtered.length + 1,
                      itemBuilder: (_, i) {
                        // Index 0 → Cardiva AI chat entry
                        if (i == 0) return const _CardivaAiTile();
                        final g = filtered[i - 1];
                        final guardianUid =
                            g['attendant_uid'] as String? ?? '';
                        final guardianName =
                            g['attendant_name'] as String? ?? 'Guardian';
                        return _GuardianTile(
                          myUid: myUid,
                          guardianUid: guardianUid,
                          guardianName: guardianName,
                          chatData: chatDataMap[guardianUid],
                        );
                      },
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

  // Direct stream subscription — avoids Riverpod caching error state when the
  // chat doc doesn't exist yet (rules deny before first message is sent).
  StreamSubscription<List<ChatMessage>>? _msgSub;
  List<ChatMessage> _messages = [];
  bool _msgLoading = true;
  bool _msgError = false;

  @override
  void initState() {
    super.initState();
    _subscribeMessages();
    ChatService.markRead(widget.myUid, widget.guardianUid).catchError((_) {});
  }

  void _subscribeMessages() {
    _msgSub?.cancel();
    if (mounted) setState(() { _msgLoading = true; _msgError = false; });
    _msgSub = ChatService.messagesStream(widget.myUid, widget.guardianUid)
        .listen(
          (msgs) {
            if (!mounted) return;
            setState(() { _messages = msgs; _msgLoading = false; _msgError = false; });
            if (msgs.isNotEmpty) _scrollToBottom();
          },
          onError: (_) {
            if (mounted) setState(() { _msgLoading = false; _msgError = true; });
          },
        );
  }

  @override
  void dispose() {
    _msgSub?.cancel();
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
      itemBuilder: (_, i) => _Bubble(msg: _messages[i], myUid: widget.myUid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
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
          Expanded(child: _buildMessageArea()),
          _InputBar(
            ctrl: _ctrl,
            onSend: _send,
            sending: false,
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
  const _Bubble({required this.msg, required this.myUid});

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
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ChatService.deleteMessage(
                        msg.senderId, msg.receiverId, msg.id);
                  } catch (_) {}
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
    return Align(
      alignment: _isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMenu(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _bg(),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: _isMe
                  ? const Radius.circular(18)
                  : const Radius.circular(4),
              bottomRight: _isMe
                  ? const Radius.circular(4)
                  : const Radius.circular(18),
            ),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.shadowLg,
                  blurRadius: 4,
                  offset: Offset(0, 2))
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
              Text(time,
                  style: TextStyle(
                      fontSize: 10, color: _fg().withValues(alpha: 0.65))),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final bool sending;
  final String hintText;
  const _InputBar({
    required this.ctrl,
    required this.onSend,
    required this.sending,
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
            onTap: sending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: sending ? AppColors.accentTint : _kHeaderColor,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
