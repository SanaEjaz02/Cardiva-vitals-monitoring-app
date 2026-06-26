import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class PatientQrScreen extends ConsumerWidget {
  const PatientQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = AuthService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      appBar: AppBar(
        backgroundColor: AppColors.bgWhite,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text('My Patient QR', style: AppTextStyles.h1.copyWith(fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              Text(
                'Show this QR code to your attendant',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'They scan it to link to your health dashboard and receive your alerts.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                        color: AppColors.shadowLg,
                        blurRadius: 20,
                        offset: Offset(0, 6))
                  ],
                ),
                child: Column(
                  children: [
                    // Cardiva logo above QR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            gradient: AppColors.heroCard,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.monitor_heart_outlined,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text('Cardiva',
                            style: AppTextStyles.h2
                                .copyWith(color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (uid.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(80),
                        child: CircularProgressIndicator(),
                      )
                    else
                      QrImageView(
                        data: uid,
                        version: QrVersions.auto,
                        size: 240,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.primaryDeep,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.primary,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text('Patient ID',
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: uid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Patient ID copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.bgLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              uid.length > 16
                                  ? '${uid.substring(0, 8)}…${uid.substring(uid.length - 6)}'
                                  : uid,
                              style: AppTextStyles.caption.copyWith(
                                  fontFamily: 'monospace',
                                  color: AppColors.textPrimary),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy_rounded,
                                size: 14, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBg.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text('How it works',
                            style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const _Step('1', 'Your attendant opens the Cardiva app and taps Scan QR.'),
                    const _Step('2', 'They point the camera at this QR code.'),
                    const _Step('3', 'Your health data and emergency alerts appear on their dashboard instantly.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String num;
  final String text;
  const _Step(this.num, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textPrimary, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
