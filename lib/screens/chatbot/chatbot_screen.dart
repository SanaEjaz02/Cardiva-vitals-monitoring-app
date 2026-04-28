import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/pill_widget.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with SingleTickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;
  late AnimationController _dotsController;

  final List<_ChatMessage> _messages = [
    _ChatMessage.user('What does my HRV reading mean?'),
    _ChatMessage.bot(
      'Heart Rate Variability (HRV) measures the variation in time between heartbeats. '
      'Your current HRV of 45ms is in the normal range — higher values generally indicate '
      'better cardiovascular fitness and stress resilience.',
      vital: _EmbeddedVital('HRV', '45 ms', VitalDisplayStatus.normal),
    ),
    _ChatMessage.user("Is my SpO₂ okay right now?"),
    _ChatMessage.bot(
      "Your SpO₂ reading of 93% is slightly below the normal threshold of 95%. "
      "This may be due to mild exertion or positioning. If it stays below 94% "
      "for more than a few minutes, consider resting and taking a deep breath.",
      vital: _EmbeddedVital('SpO₂', '93%', VitalDisplayStatus.warning),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    setState(() {
      _messages.add(_ChatMessage.user(text));
      _isTyping = true;
    });
    _scrollToBottom();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(_ChatMessage.bot(
        "I'm analyzing your health data and will provide personalized insights based on your vitals.",
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cardiva AI', style: AppTextStyles.h1),
                const SizedBox(width: 4),
                const Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFF8B5CF6), size: 18),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('Online', style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (_isTyping && i == _messages.length) {
                  return _TypingIndicator(controller: _dotsController);
                }
                return _MessageBubble(message: _messages[i]);
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              12, 10, 12, MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: const BoxDecoration(
              color: AppColors.bgWhite,
              border: Border(top: BorderSide(color: Color(0xFFEAEEF5))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.mic_none_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () {},
                ),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: TextField(
                      controller: _inputCtrl,
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(
                        hintText: 'Ask about your health…',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        filled: false,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: AppTextStyles.body.copyWith(
                color: isUser ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (message.vital != null) ...[
              const SizedBox(height: 8),
              _EmbeddedVitalCard(vital: message.vital!),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmbeddedVitalCard extends StatelessWidget {
  final _EmbeddedVital vital;
  const _EmbeddedVitalCard({required this.vital});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(vital.status);
    final pillVariant = vital.status == VitalDisplayStatus.normal
        ? PillVariant.success
        : vital.status == VitalDisplayStatus.warning
            ? PillVariant.warning
            : PillVariant.danger;
    final label = vital.status == VitalDisplayStatus.normal
        ? 'Normal'
        : vital.status == VitalDisplayStatus.warning
            ? 'Warning'
            : 'Critical';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vital.name, style: AppTextStyles.caption),
                Text(vital.value, style: AppTextStyles.h2),
              ],
            ),
          ),
          PillWidget(label, variant: pillVariant),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final AnimationController controller;
  const _TypingIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final anim = Tween<double>(begin: 0, end: -6).animate(
              CurvedAnimation(
                parent: controller,
                curve: Interval(i * 0.2, (i * 0.2 + 0.4).clamp(0.0, 1.0),
                    curve: Curves.easeInOut),
              ),
            );
            return AnimatedBuilder(
              animation: controller,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, anim.value),
                child: Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final _EmbeddedVital? vital;
  _ChatMessage.user(this.text)
      : isUser = true,
        vital = null;
  _ChatMessage.bot(this.text, {this.vital}) : isUser = false;
}

class _EmbeddedVital {
  final String name;
  final String value;
  final VitalDisplayStatus status;
  const _EmbeddedVital(this.name, this.value, this.status);
}
