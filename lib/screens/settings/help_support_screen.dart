import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final List<bool> _expanded =
      List.generate(_faqs.length, (_) => false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Help & Support', style: AppTextStyles.h1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Search hint ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.shadowSm,
                      blurRadius: 8,
                      offset: Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 10),
                  Text('Search help articles…',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── FAQ ────────────────────────────────────────────────────
            Text('Frequently Asked Questions',
                style: AppTextStyles.caption
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.shadowSm,
                      blurRadius: 12,
                      offset: Offset(0, 2))
                ],
              ),
              child: Column(
                children: List.generate(_faqs.length, (i) {
                  final faq = _faqs[i];
                  final isLast = i == _faqs.length - 1;
                  return Column(
                    children: [
                      InkWell(
                        onTap: () => setState(
                            () => _expanded[i] = !_expanded[i]),
                        borderRadius: BorderRadius.vertical(
                          top: i == 0
                              ? const Radius.circular(16)
                              : Radius.zero,
                          bottom: isLast
                              ? const Radius.circular(16)
                              : Radius.zero,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(faq.question,
                                    style: AppTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w500)),
                              ),
                              AnimatedRotation(
                                turns: _expanded[i] ? 0.5 : 0,
                                duration:
                                    const Duration(milliseconds: 200),
                                child: const Icon(
                                    Icons.expand_more_rounded,
                                    color: AppColors.textSecondary,
                                    size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(
                              left: 16, right: 16, bottom: 14),
                          child: Text(faq.answer,
                              style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary)),
                        ),
                        crossFadeState: _expanded[i]
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                      ),
                      if (!isLast)
                        const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: AppColors.divider),
                    ],
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),

            // ── Contact us ─────────────────────────────────────────────
            Text('Contact Us',
                style: AppTextStyles.caption
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: AppColors.shadowSm,
                      blurRadius: 12,
                      offset: Offset(0, 2))
                ],
              ),
              child: Column(
                children: [
                  _ContactRow(
                    icon: Icons.email_outlined,
                    label: 'Email Support',
                    value: 'support@cardiva.app',
                    onTap: () => _launch('mailto:support@cardiva.app'),
                  ),
                  const Divider(
                      height: 1,
                      indent: 64,
                      endIndent: 16,
                      color: AppColors.divider),
                  _ContactRow(
                    icon: Icons.language_rounded,
                    label: 'Website',
                    value: 'cardiva.app',
                    onTap: () =>
                        _launch('https://cardiva.app'),
                  ),
                  const Divider(
                      height: 1,
                      indent: 64,
                      endIndent: 16,
                      color: AppColors.divider),
                  _ContactRow(
                    icon: Icons.policy_outlined,
                    label: 'Privacy Policy',
                    value: 'View policy',
                    onTap: () =>
                        _launch('https://cardiva.app/privacy'),
                    last: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── App info ───────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Text('Cardiva Health Monitor',
                      style: AppTextStyles.caption
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Version 1.0.0 · Build 1',
                      style: AppTextStyles.caption),
                  const SizedBox(height: 2),
                  Text('© 2025 Cardiva. All rights reserved.',
                      style: AppTextStyles.caption),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

// ── FAQ data ───────────────────────────────────────────────────────────────

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}

const _faqs = [
  _Faq(
    'How does Cardiva detect emergencies?',
    'Cardiva continuously monitors your vital signs using the paired '
        'wearable band. When readings exceed safe thresholds, or a fall is '
        'detected, it automatically triggers an alert countdown and notifies '
        'your registered emergency contacts.',
  ),
  _Faq(
    'How accurate is the fall detection?',
    'Fall detection uses accelerometer and gyroscope data processed through '
        'our AI model, achieving over 92% sensitivity in controlled testing. '
        'Sensitivity can be adjusted in Settings → Alerts & Thresholds.',
  ),
  _Faq(
    'Can I use Cardiva without a wearable?',
    'The live vitals and emergency detection features require a paired '
        'Cardiva Band. However, you can still view health history, reports, '
        'and use the AI health assistant (Ask AI) without a device connected.',
  ),
  _Faq(
    'How is my health data stored?',
    'All health data is encrypted locally on your device. If Cloud Sync is '
        'enabled (Settings → Privacy), an encrypted copy is stored on our '
        'servers. We never sell your health data to third parties.',
  ),
  _Faq(
    'How do I add or change emergency contacts?',
    'Go to Profile → Emergency Contacts. You can add up to 5 contacts, '
        'each with a name, phone number, and relationship. During an emergency, '
        'all active contacts are notified simultaneously via SMS.',
  ),
  _Faq(
    'What happens during an emergency countdown?',
    'When an emergency is detected, a 25-second countdown begins. You can '
        'cancel it if it is a false alarm. If the countdown reaches zero, alerts '
        'are sent automatically. You can also send the alert immediately.',
  ),
];

// ── Contact row ────────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool last;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        bottom: last ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primaryBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.body),
                  Text(value, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded,
                color: AppColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
