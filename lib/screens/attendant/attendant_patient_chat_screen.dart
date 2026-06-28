import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_message.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AttendantPatientChatScreen extends ConsumerStatefulWidget {
  final String patientUid;
  final String patientName;

  const AttendantPatientChatScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
  });

  @override
  ConsumerState<AttendantPatientChatScreen> createState() =>
      _AttendantPatientChatScreenState();
}

class _AttendantPatientChatScreenState
    extends ConsumerState<AttendantPatientChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<List<ChatMessage>>? _msgSub;
  Timer? _refreshTimer;
  List<ChatMessage> _messages = [];
  bool _msgLoading = true;
  bool _msgError = false;

  final _selectedIds = <String>{};
  bool get _inSelectionMode => _selectedIds.isNotEmpty;

  void _toggleSelect(String id) => setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      });

  Future<void> _deleteSelected() async {
    final toDelete = _selectedIds.toList();
    final msgs = _messages.where((m) => toDelete.contains(m.id)).toList();
    setState(() {
      _selectedIds.clear();
      _messages = _messages.where((m) => !toDelete.contains(m.id)).toList();
    });
    for (final m in msgs) {
      ChatService.deleteMessage(m.senderId, m.receiverId, m.id).catchError((_) {});
    }
  }

  String get _myUid => AuthService.currentUser?.uid ?? '';
  String get _myName => ref.read(userProvider)?.name ?? 'Guardian';

  @override
  void initState() {
    super.initState();
    _subscribeMessages();
    _refreshFromServer();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshFromServer(),
    );
    ChatService.markRead(_myUid, widget.patientUid).catchError((_) {});
  }

  Future<void> _refreshFromServer() async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(ChatService.chatId(widget.patientUid, _myUid))
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get(const GetOptions(source: Source.server));
    } catch (_) {}
  }

  void _subscribeMessages() {
    _msgSub?.cancel();
    if (mounted) setState(() { _msgLoading = true; _msgError = false; });
    _msgSub = ChatService.messagesStream(widget.patientUid, _myUid)
        .listen(
          (msgs) {
            if (!mounted) return;
            setState(() { _messages = msgs; _msgLoading = false; _msgError = false; });
            if (msgs.isNotEmpty) _scrollToBottom();
            ChatService.markRead(_myUid, widget.patientUid).catchError((_) {});
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
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    final wasError = _msgError;

    final now = DateTime.now();
    final tempMsg = ChatMessage(
      id: 'temp_${now.millisecondsSinceEpoch}',
      senderId: _myUid,
      receiverId: widget.patientUid,
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

    // Fire-and-forget — message is already visible, UI never spins.
    ChatService.sendMessage(
      patientUid: widget.patientUid,
      guardianUid: _myUid,
      senderUid: _myUid,
      senderName: _myName,
      text: text,
    ).then((_) {
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
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageArea() {
    if (_msgLoading) return const Center(child: CircularProgressIndicator());
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
            Text('No messages yet',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Start the conversation', style: AppTextStyles.caption),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _MessageBubble(
        msg: _messages[i],
        myUid: _myUid,
        isSelected: _selectedIds.contains(_messages[i].id),
        isSelectionMode: _inSelectionMode,
        onSelectMessage: _toggleSelect,
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
                          widget.patientName.isNotEmpty
                              ? widget.patientName[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.patientName,
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
          _InputBar(ctrl: _ctrl, onSend: _send, sending: false),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final String myUid;
  final bool isSelected;
  final bool isSelectionMode;
  final void Function(String id)? onSelectMessage;

  const _MessageBubble({
    required this.msg,
    required this.myUid,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onSelectMessage,
  });

  bool get _isMe => msg.senderId == myUid;

  Color _bubbleColor() {
    if (msg.type == MessageType.report) return AppColors.primaryBg;
    return _isMe ? AppColors.primaryDeep : Colors.white;
  }

  Color _textColor() {
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

  Widget _buildText() {
    final mapsUrl = _extractMapsUrl();
    if (mapsUrl == null) {
      return Text(msg.content,
          style: TextStyle(fontSize: 14, color: _textColor(), height: 1.4));
    }

    final bodyText = msg.content
        .replaceFirst(RegExp(r'📍\s*https://maps\.google\.com/\?q=[^\s]+'), '')
        .trimRight();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bodyText.isNotEmpty) ...[
          Text(bodyText,
              style: TextStyle(fontSize: 14, color: _textColor(), height: 1.4)),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: () => launchUrl(Uri.parse(mapsUrl),
              mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _isMe ? 0.18 : 0.0),
              border: Border.all(color: _textColor().withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_rounded,
                    size: 16,
                    color: _isMe ? Colors.white : AppColors.primary),
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
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? _bubbleColor().withValues(alpha: 0.6)
              : _bubbleColor(),
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
                    Icon(Icons.description_rounded,
                        size: 14, color: _textColor()),
                    const SizedBox(width: 4),
                    Text('Health Report',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _textColor())),
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
                        fontSize: 10,
                        color: _textColor().withValues(alpha: 0.65))),
                if (_isMe) ...[
                  const SizedBox(width: 3),
                  _TickIcon(isSent: !msg.id.startsWith('temp_'), isRead: msg.isRead,
                      color: _textColor()),
                ],
              ],
            ),
          ],
        ),
      ),
    );

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

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final bool sending;
  const _InputBar(
      {required this.ctrl, required this.onSend, required this.sending});

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
                hintText: 'Message patient…',
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
                color: sending ? AppColors.accentTint : AppColors.primaryDeep,
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

// Single tick = sending, double grey = sent, double primary = read
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
