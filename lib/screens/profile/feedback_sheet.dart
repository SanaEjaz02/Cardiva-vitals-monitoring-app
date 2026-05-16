import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

void showFeedbackSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _FeedbackSheet(),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  String? _category;
  final _messageCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  late final AnimationController _successCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim =
        CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);
    _messageCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  String get _firstName =>
      FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ??
      'there';

  Future<void> _submit() async {
    if (_rating == 0 || _category == null) return;
    setState(() => _submitting = true);
    final user = FirebaseAuth.instance.currentUser;
    try {
      await FirestoreService.saveFeedback(
        userId: user?.uid ?? 'guest',
        userEmail: user?.email ?? '',
        userName: user?.displayName ?? 'Patient',
        rating: _rating,
        category: _category!,
        message: _messageCtrl.text.trim(),
      );
    } catch (_) {}
    if (mounted) {
      setState(() {
        _submitting = false;
        _submitted = true;
      });
      _successCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _submitted ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  // ── Success view ────────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 52),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Thank you, $_firstName!',
          style: AppTextStyles.h1
              .copyWith(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Your feedback helps us improve Cardiva\nfor everyone.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body
              .copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Done',
              style: AppTextStyles.body.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // ── Form view ───────────────────────────────────────────────────────────────

  Widget _buildForm() {
    final canSubmit = _rating > 0 && _category != null && !_submitting;
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 22),
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0096C7), Color(0xFF023E8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.rate_review_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Send Feedback',
                    style: AppTextStyles.h2
                        .copyWith(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 2),
                Text('We read every response',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 26),
        // Star rating
        Text('How would you rate Cardiva?',
            style:
                AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _StarRating(
            rating: _rating, onChanged: (r) => setState(() => _rating = r)),
        const SizedBox(height: 26),
        // Category chips
        Text("What's this about?",
            style:
                AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _CategoryChips(
            selected: _category,
            onSelected: (c) => setState(() => _category = c)),
        const SizedBox(height: 26),
        // Message
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your message',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600)),
            Text(
              '${_messageCtrl.text.length}/300',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _messageCtrl,
          maxLines: 4,
          maxLength: 300,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          decoration: InputDecoration(
            hintText: 'Describe your experience...',
            hintStyle: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.45)),
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 26),
        // Submit button
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor:
                  AppColors.primary.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    'Send Feedback',
                    style: AppTextStyles.body.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Star rating ─────────────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  static const _labels = [
    '',
    'Poor',
    'Fair',
    'Good',
    'Very Good',
    'Excellent'
  ];

  const _StarRating({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          final filled = i < rating;
          return GestureDetector(
            onTap: () => onChanged(i + 1),
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  key: ValueKey(filled),
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: filled
                      ? AppColors.warning
                      : AppColors.textSecondary.withValues(alpha: 0.3),
                  size: 38,
                ),
              ),
            ),
          );
        }),
        if (rating > 0) ...[
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              key: ValueKey(rating),
              _labels[rating],
              style: AppTextStyles.body.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Category chips ───────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;

  static const _items = [
    _ChipData('Bug Report', Icons.bug_report_rounded, AppColors.danger),
    _ChipData('Feature Request', Icons.lightbulb_rounded, AppColors.warning),
    _ChipData('Health Data', Icons.favorite_rounded, Color(0xFFEC4899)),
    _ChipData('General', Icons.chat_bubble_rounded, AppColors.primary),
  ];

  const _CategoryChips(
      {required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _items.map((item) {
        final isSelected = selected == item.label;
        return GestureDetector(
          onTap: () => onSelected(item.label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? item.color.withValues(alpha: 0.10)
                  : const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? item.color : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon,
                    size: 16,
                    color: isSelected
                        ? item.color
                        : AppColors.textSecondary
                            .withValues(alpha: 0.5)),
                const SizedBox(width: 7),
                Text(
                  item.label,
                  style: AppTextStyles.caption.copyWith(
                    color: isSelected
                        ? item.color
                        : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChipData {
  final String label;
  final IconData icon;
  final Color color;
  const _ChipData(this.label, this.icon, this.color);
}
