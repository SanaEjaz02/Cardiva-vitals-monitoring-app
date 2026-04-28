import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/step_indicator.dart';
import '../../router/app_router.dart';

class DevicePairScreen extends StatefulWidget {
  const DevicePairScreen({super.key});

  @override
  State<DevicePairScreen> createState() => _DevicePairScreenState();
}

class _DevicePairScreenState extends State<DevicePairScreen>
    with TickerProviderStateMixin {
  late List<AnimationController> _ringControllers;
  bool _deviceFound = true; // show found state for demo

  @override
  void initState() {
    super.initState();
    _ringControllers = List.generate(3, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      )..repeat();
      Future.delayed(Duration(milliseconds: i * 600), () {
        if (mounted) ctrl.repeat();
      });
      return ctrl;
    });
  }

  @override
  void dispose() {
    for (final c in _ringControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _proceed() =>
      Navigator.pushNamed(context, AppRouter.setupContact);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.arrow_back_ios_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                        child: StepIndicator(current: 2, total: 3)),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Connect your device', style: AppTextStyles.h1),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Make sure Bluetooth is on and your Cardiva band is nearby.',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            // Pulse rings
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ...List.generate(3, (i) {
                    final ctrl = _ringControllers[i];
                    return AnimatedBuilder(
                      animation: ctrl,
                      builder: (_, __) {
                        final t = ctrl.value;
                        return Opacity(
                          opacity: (1 - t) *
                              [1.0, 0.6, 0.3][i],
                          child: Container(
                            width: 120 + t * 80,
                            height: 120 + t * 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  // Center bluetooth icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      gradient: AppColors.heroCard,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bluetooth_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Scanning for devices…',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 28),
            // Device found card
            if (_deviceFound)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgWhite,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowSm,
                        blurRadius: 16,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.watch_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cardiva Band 1',
                                style: AppTextStyles.h2),
                            Text('Model CB-100',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      const Icon(Icons.signal_cellular_alt_rounded,
                          color: AppColors.success, size: 20),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _proceed,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Connect'),
                      ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: Text(
                'Enter device code manually',
                style: AppTextStyles.caption.copyWith(color: AppColors.primary),
              ),
            ),
            TextButton(
              onPressed: _proceed,
              child: Text(
                'Skip for now',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
