import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/pill_widget.dart';

// ── Constants ──────────────────────────────────────────────────────────────

const _kSystemPrompt =
    'You are a helpful health assistant. Answer health and medical queries '
    'in a clear, friendly manner. Always recommend consulting a qualified '
    'doctor for serious concerns. Never diagnose. Always add disclaimers.';

const _kSuggestions = [
  'What does my HRV reading mean?',
  'Is my SpO₂ safe right now?',
  'Explain my current heart rate',
  'Tips for improving sleep quality',
  'What is my cardiac risk score?',
];

// ── Root widget ────────────────────────────────────────────────────────────

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

// ── State ──────────────────────────────────────────────────────────────────

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  late AnimationController _dotsCtrl;
  late AnimationController _pulseCtrl;

  String _groqApiKey = '';
  bool _isTyping = false;
  bool _showScrollBtn = false;

  List<_ChatSession> _sessions = [];
  _ChatSession? _current;

  @override
  void initState() {
    super.initState();
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _groqApiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    _scrollCtrl.addListener(_onScroll);
    _loadSessions();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _dotsCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom =
        _scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset < 120;
    if (!atBottom && !_showScrollBtn) setState(() => _showScrollBtn = true);
    if (atBottom && _showScrollBtn) setState(() => _showScrollBtn = false);
  }

  // ── Session persistence ────────────────────────────────────────────────

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cardiva_chat_sessions');
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      setState(() {
        _sessions = list
            .map((e) => _ChatSession.fromJson(e as Map<String, dynamic>))
            .toList();
        if (_sessions.isNotEmpty) _current = _sessions.first;
      });
    } catch (_) {}
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cardiva_chat_sessions',
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }

  void _newSession() {
    final s = _ChatSession(
      id: const Uuid().v4(),
      name: 'New Chat',
      createdAt: DateTime.now(),
    );
    setState(() {
      _sessions.insert(0, s);
      _current = s;
    });
    _saveSessions();
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _switchSession(_ChatSession s) {
    setState(() => _current = s);
    if (Navigator.canPop(context)) Navigator.pop(context);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToBottom(jump: true));
  }

  void _deleteSession(_ChatSession s) {
    setState(() {
      _sessions.remove(s);
      if (_current == s) {
        _current = _sessions.isNotEmpty ? _sessions.first : null;
      }
    });
    _saveSessions();
  }

  void _renameSession(_ChatSession s, String name) {
    setState(() => s.name = name);
    _saveSessions();
  }

  Future<void> _showRenameDialog(_ChatSession s) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameDialog(initialName: s.name),
    );
    if (result != null && result.isNotEmpty) _renameSession(s, result);
  }

  // ── Messaging ──────────────────────────────────────────────────────────

  Future<void> _sendMessage([String? preset]) async {
    if (_current == null) _newSession();

    final text = preset ?? _inputCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;
    _inputCtrl.clear();
    HapticFeedback.lightImpact();

    if (_current!.messages.isEmpty) {
      _current!.name =
          text.length > 38 ? '${text.substring(0, 38)}…' : text;
    }

    setState(() {
      _current!.messages.add(_ChatMessage.user(text));
      _isTyping = true;
    });
    _scrollToBottom();
    _current!.apiHistory.add({'role': 'user', 'content': text});

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': _kSystemPrompt},
            ..._current!.apiHistory,
          ],
          'max_tokens': 1024,
          'temperature': 0.7,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = (data['choices'] as List).first['message']['content']
                ?.toString()
                .trim() ??
            '';
        _current!.apiHistory.add({'role': 'assistant', 'content': reply});
        setState(() {
          _isTyping = false;
          _current!.messages.add(_ChatMessage.bot(
            reply.isNotEmpty
                ? reply
                : 'I could not generate a response. Please try again.',
          ));
        });
      } else {
        _current!.apiHistory.removeLast();
        setState(() {
          _isTyping = false;
          _current!.messages
              .add(_ChatMessage.bot('Sorry, something went wrong. Please try again.'));
        });
      }
    } catch (_) {
      if (!mounted) return;
      _current!.apiHistory.removeLast();
      setState(() {
        _isTyping = false;
        _current!.messages.add(_ChatMessage.bot(
            'Sorry, check your connection and try again.'));
      });
    }
    _saveSessions();
    _scrollToBottom();
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (jump) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      } else {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasMessages = _current != null && _current!.messages.isNotEmpty;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: _buildAppBar(),
      endDrawer: _buildHistoryDrawer(),
      body: Column(
        children: [
          if (hasMessages) _buildDisclaimerBanner(),
          Expanded(
            child: !hasMessages
                ? _WelcomeView(
                    pulseController: _pulseCtrl,
                    onSuggestionTap: _sendMessage,
                    suggestions: _kSuggestions,
                  )
                : _buildChatList(),
          ),
          if (hasMessages) _buildSuggestionChips(),
          _buildInputBar(context),
        ],
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
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
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withOpacity(0.15 + _pulseCtrl.value * 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white
                          .withOpacity(0.3 + _pulseCtrl.value * 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 17),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Cardiva AI', style: AppTextStyles.h2White()),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Online · Health Assistant',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded,
                  color: Colors.white, size: 22),
              tooltip: 'Chat history',
              onPressed: () =>
                  _scaffoldKey.currentState?.openEndDrawer(),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => _showInfoSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── History drawer ─────────────────────────────────────────────────────

  Widget _buildHistoryDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: const Color(0xFF111827),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDeep],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Conversations',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            // New Chat button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _newSession,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDeep],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('New Chat',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'RECENT',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: 6),
            const Divider(color: Color(0xFF1F2937), thickness: 1),
            // Session list
            Expanded(
              child: _sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              color: Colors.white24, size: 44),
                          const SizedBox(height: 12),
                          const Text('No conversations yet',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _sessions.length,
                      itemBuilder: (_, i) =>
                          _buildSessionTile(_sessions[i]),
                    ),
            ),
            const Divider(color: Color(0xFF1F2937)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: const [
                  Icon(Icons.lock_outline_rounded,
                      color: Colors.white38, size: 13),
                  SizedBox(width: 8),
                  Text('Private & Secure',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(_ChatSession s) {
    final isActive = _current?.id == s.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: AppColors.primary.withOpacity(0.3))
            : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: Icon(
          Icons.chat_bubble_outline_rounded,
          color: isActive ? AppColors.primary : Colors.white38,
          size: 16,
        ),
        title: Text(
          s.name,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight:
                isActive ? FontWeight.w600 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDate(s.createdAt),
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              color: Colors.white38, size: 16),
          color: const Color(0xFF1F2937),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          onSelected: (val) async {
            if (val == 'rename') {
              // Close the endDrawer first so its InheritedWidget subtree is
              // fully unmounted before the dialog route is pushed. Showing a
              // dialog while the Drawer is open causes _dependents.isEmpty
              // assertion failures inside framework.dart.
              _scaffoldKey.currentState?.closeEndDrawer();
              await Future.delayed(const Duration(milliseconds: 300));
              if (mounted) await _showRenameDialog(s);
            }
            if (val == 'delete') _deleteSession(s);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'rename',
              child: Row(children: const [
                Icon(Icons.edit_outlined, color: Colors.white70, size: 15),
                SizedBox(width: 10),
                Text('Rename',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: const [
                Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 15),
                SizedBox(width: 10),
                Text('Delete',
                    style: TextStyle(
                        color: Color(0xFFEF4444), fontSize: 13)),
              ]),
            ),
          ],
        ),
        onTap: () => _switchSession(s),
      ),
    );
  }

  // ── Disclaimer banner ──────────────────────────────────────────────────

  Widget _buildDisclaimerBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBEB),
        border: Border(
            bottom: BorderSide(color: Color(0xFFFDE68A), width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFF59E0B), size: 13),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'For informational purposes only — always consult a qualified doctor.',
              style: AppTextStyles.caption.copyWith(
                  color: const Color(0xFF92400E), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat list ──────────────────────────────────────────────────────────

  Widget _buildChatList() {
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount:
              _current!.messages.length + (_isTyping ? 1 : 0),
          itemBuilder: (_, i) {
            if (_isTyping && i == _current!.messages.length) {
              return _TypingIndicator(controller: _dotsCtrl);
            }
            return _MessageBubble(
              message: _current!.messages[i],
              key: ValueKey(
                  '${_current!.id}_${_current!.messages[i].timestamp.millisecondsSinceEpoch}'),
            );
          },
        ),
        if (_showScrollBtn)
          Positioned(
            right: 16,
            bottom: 10,
            child: GestureDetector(
              onTap: _scrollToBottom,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
      ],
    );
  }

  // ── Suggestion chips ───────────────────────────────────────────────────

  Widget _buildSuggestionChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _sendMessage(_kSuggestions[i]),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Text(
              _kSuggestions[i],
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────────────────

  Widget _buildInputBar(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: EdgeInsets.only(bottom: bottomPad > 0 ? bottomPad - 4 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLg,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.mic_none_rounded,
                  color: AppColors.textSecondary),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                style: AppTextStyles.body,
                maxLines: null,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Ask about your health…',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  filled: false,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDeep],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_upward_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  // ── Info sheet ─────────────────────────────────────────────────────────

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InfoSheet(),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Welcome view ───────────────────────────────────────────────────────────

class _WelcomeView extends StatefulWidget {
  final AnimationController pulseController;
  final void Function(String) onSuggestionTap;
  final List<String> suggestions;

  const _WelcomeView({
    required this.pulseController,
    required this.onSuggestionTap,
    required this.suggestions,
  });

  @override
  State<_WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<_WelcomeView> {
  late PageController _pageCtrl;
  Timer? _timer;
  int _page = 0;

  static const _tips = [
    (Icons.water_drop_rounded, Color(0xFF3B82F6), 'Stay Hydrated',
        'Drink 8 glasses of water daily to keep your heart working efficiently.'),
    (Icons.air_rounded, Color(0xFF8B5CF6), 'Deep Breathing',
        'Practice 5 minutes of deep breathing to lower your resting heart rate.'),
    (Icons.directions_walk_rounded, Color(0xFF10B981), 'Move Daily',
        'Walking 10,000 steps daily reduces cardiovascular risk by up to 30%.'),
    (Icons.bedtime_rounded, Color(0xFF6366F1), 'Quality Sleep',
        '7–9 hours of sleep allows your heart to fully rest and recover overnight.'),
    (Icons.self_improvement_rounded, Color(0xFFF59E0B), 'Manage Stress',
        'Chronic stress raises blood pressure. Try 10 minutes of meditation daily.'),
    (Icons.restaurant_rounded, Color(0xFF06B6D4), 'Heart-Healthy Diet',
        'Omega-3 rich foods like salmon and walnuts actively support cardiac health.'),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.88);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _page = (_page + 1) % _tips.length);
      _pageCtrl.animateToPage(
        _page,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        children: [
          // Pulsing AI avatar
          AnimatedBuilder(
            animation: widget.pulseController,
            builder: (_, child) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 112 + widget.pulseController.value * 16,
                  height: 112 + widget.pulseController.value * 16,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(
                        (0.05 - widget.pulseController.value * 0.04)
                            .clamp(0.0, 0.05)),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 94 + widget.pulseController.value * 8,
                  height: 94 + widget.pulseController.value * 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(
                        (0.1 - widget.pulseController.value * 0.08)
                            .clamp(0.0, 0.1)),
                    shape: BoxShape.circle,
                  ),
                ),
                child!,
              ],
            ),
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDeep],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(Icons.favorite_rounded,
                  color: Colors.white, size: 34),
            ),
          ),
          const SizedBox(height: 18),
          Text("Hi, I'm Cardiva AI", style: AppTextStyles.h1),
          const SizedBox(height: 6),
          Text(
            'Your personal cardiac health assistant.\nAsk me anything about your vitals.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Health tips carousel
          SizedBox(
            height: 108,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: _tips.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final tip = _tips[i];
                final isCenter = i == _page;
                return AnimatedScale(
                  scale: isCenter ? 1.0 : 0.93,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tip.$2.withOpacity(0.13),
                          tip.$2.withOpacity(0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: tip.$2.withOpacity(0.25)),
                      boxShadow: isCenter
                          ? [
                              BoxShadow(
                                color: tip.$2.withOpacity(0.18),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: tip.$2.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(tip.$1, color: tip.$2, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text(
                                tip.$3,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tip.$4,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Page indicator dots
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _tips.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: i == _page ? 18 : 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == _page
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _FeatureBadge(
                  label: 'Vitals Analysis',
                  icon: Icons.monitor_heart_outlined),
              _FeatureBadge(
                  label: 'Health Advice',
                  icon: Icons.lightbulb_outline_rounded),
              _FeatureBadge(
                  label: 'Risk Insights',
                  icon: Icons.security_outlined),
              _FeatureBadge(
                  label: 'Trend Reports',
                  icon: Icons.trending_up_rounded),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Suggested questions',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...widget.suggestions.map(
            (s) => _SuggestionTile(
              text: s,
              onTap: () => widget.onSuggestionTap(s),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature badge ──────────────────────────────────────────────────────────

class _FeatureBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FeatureBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentTint),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggestion tile ────────────────────────────────────────────────────────

class _SuggestionTile extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SuggestionTile({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLg,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: AppTextStyles.body)),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────

class _MessageBubble extends StatefulWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message, super.key});
  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.message.text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    return GestureDetector(
      onLongPress: _copyText,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser) ...[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDeep],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        color: Colors.white, size: 13),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width * 0.74),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                  AppColors.primary,
                                  AppColors.primaryDeep
                                ])
                          : null,
                      color: isUser ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      boxShadow: isUser
                          ? null
                          : const [
                              BoxShadow(
                                color: AppColors.shadowLg,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                    ),
                    child: isUser
                        ? Text(
                            widget.message.text,
                            style: AppTextStyles.body
                                .copyWith(color: Colors.white),
                          )
                        : MarkdownBody(
                            data: widget.message.text,
                            shrinkWrap: true,
                            styleSheet: MarkdownStyleSheet(
                              p: AppTextStyles.body.copyWith(
                                  color: AppColors.textPrimary),
                              strong: AppTextStyles.body.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700),
                              em: AppTextStyles.body.copyWith(
                                  color: AppColors.textPrimary,
                                  fontStyle: FontStyle.italic),
                              h1: AppTextStyles.h1
                                  .copyWith(color: AppColors.textPrimary),
                              h2: AppTextStyles.h2
                                  .copyWith(color: AppColors.textPrimary),
                              h3: AppTextStyles.body.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700),
                              listBullet: AppTextStyles.body.copyWith(
                                  color: AppColors.primary),
                              blockquoteDecoration: BoxDecoration(
                                color: AppColors.primaryBg,
                                borderRadius: BorderRadius.circular(4),
                                border: const Border(
                                  left: BorderSide(
                                      color: AppColors.primary, width: 3),
                                ),
                              ),
                              code: AppTextStyles.caption.copyWith(
                                fontFamily: 'monospace',
                                backgroundColor:
                                    AppColors.primaryBg,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
            // Timestamp + thumbs
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : 38,
                right: isUser ? 4 : 0,
                top: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary),
                  ),
                  if (!isUser) ...[
                    const SizedBox(width: 10),
                    _ThumbBtn(
                      icon: Icons.thumb_up_outlined,
                      activeIcon: Icons.thumb_up_rounded,
                      isActive: widget.message.rating == 1,
                      activeColor: AppColors.success,
                      onTap: () => setState(() {
                        widget.message.rating =
                            widget.message.rating == 1 ? 0 : 1;
                      }),
                    ),
                    const SizedBox(width: 6),
                    _ThumbBtn(
                      icon: Icons.thumb_down_outlined,
                      activeIcon: Icons.thumb_down_rounded,
                      isActive: widget.message.rating == -1,
                      activeColor: const Color(0xFFF59E0B),
                      onTap: () => setState(() {
                        widget.message.rating =
                            widget.message.rating == -1 ? 0 : -1;
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

class _ThumbBtn extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
  const _ThumbBtn({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Icon(
          isActive ? activeIcon : icon,
          size: 14,
          color: isActive
              ? activeColor
              : AppColors.textSecondary.withOpacity(0.45),
        ),
      );
}

// ── Typing indicator ───────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  final AnimationController controller;
  const _TypingIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDeep],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 13),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.shadowLg,
                    blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final anim = Tween<double>(begin: 0, end: -6).animate(
                  CurvedAnimation(
                    parent: controller,
                    curve: Interval(
                      i * 0.2,
                      (i * 0.2 + 0.4).clamp(0.0, 1.0),
                      curve: Curves.easeInOut,
                    ),
                  ),
                );
                return AnimatedBuilder(
                  animation: controller,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, anim.value),
                    child: Container(
                      width: 7,
                      height: 7,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info bottom sheet ──────────────────────────────────────────────────────

class _InfoSheet extends StatelessWidget {
  const _InfoSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDeep],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About Cardiva AI', style: AppTextStyles.h2),
                  Text('Your cardiac health assistant',
                      style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'What I can help with',
            style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          const _InfoRow(
            icon: Icons.monitor_heart_outlined,
            color: AppColors.primary,
            text:
                'Explain your vitals — HRV, SpO₂, heart rate, blood pressure',
          ),
          const _InfoRow(
            icon: Icons.lightbulb_outline_rounded,
            color: Color(0xFF8B5CF6),
            text:
                'Give personalised health tips based on your readings',
          ),
          const _InfoRow(
            icon: Icons.trending_up_rounded,
            color: AppColors.success,
            text:
                'Identify trends and flag unusual patterns in your data',
          ),
          const _InfoRow(
            icon: Icons.help_outline_rounded,
            color: Color(0xFFF59E0B),
            text: 'Answer general questions about cardiac health',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.warning.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cardiva AI is for informational purposes only and does not '
                    'replace professional medical advice. Always consult a '
                    'qualified healthcare provider for diagnosis or treatment.',
                    style: AppTextStyles.caption.copyWith(
                        color: const Color(0xFF92400E), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Your conversations are private and not shared.',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoRow(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text, style: AppTextStyles.body),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rename dialog ──────────────────────────────────────────────────────────

class _RenameDialog extends StatefulWidget {
  final String initialName;
  const _RenameDialog({required this.initialName});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Rename Chat',
          style: TextStyle(color: Colors.white, fontSize: 16)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Chat name',
          hintStyle: const TextStyle(color: Colors.white38),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text('Save', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final _EmbeddedVital? vital;
  int rating = 0; // 1=up, -1=down, 0=none

  _ChatMessage.user(this.text, {DateTime? timestamp})
      : isUser = true,
        vital = null,
        timestamp = timestamp ?? DateTime.now();

  _ChatMessage.bot(this.text, {this.vital, DateTime? timestamp})
      : isUser = false,
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'rating': rating,
      };

  static _ChatMessage fromJson(Map<String, dynamic> j) {
    final msg = (j['isUser'] as bool)
        ? _ChatMessage.user(j['text'] as String,
            timestamp: DateTime.parse(j['timestamp'] as String))
        : _ChatMessage.bot(j['text'] as String,
            timestamp: DateTime.parse(j['timestamp'] as String));
    msg.rating = (j['rating'] as int?) ?? 0;
    return msg;
  }
}

class _ChatSession {
  final String id;
  String name;
  final DateTime createdAt;
  final List<_ChatMessage> messages;
  final List<Map<String, String>> apiHistory;

  _ChatSession({
    required this.id,
    required this.name,
    required this.createdAt,
  })  : messages = [],
        apiHistory = [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'apiHistory': apiHistory,
      };

  factory _ChatSession.fromJson(Map<String, dynamic> j) {
    final s = _ChatSession(
      id: j['id'] as String,
      name: j['name'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
    for (final m in (j['messages'] as List?) ?? []) {
      s.messages.add(_ChatMessage.fromJson(m as Map<String, dynamic>));
    }
    for (final h in (j['apiHistory'] as List?) ?? []) {
      s.apiHistory.add(Map<String, String>.from(h as Map));
    }
    return s;
  }
}

class _EmbeddedVital {
  final String name;
  final String value;
  final VitalDisplayStatus status;
  const _EmbeddedVital(this.name, this.value, this.status);
}
