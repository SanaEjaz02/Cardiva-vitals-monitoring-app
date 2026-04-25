import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/vital_status.dart';
import '../../providers/vital_provider.dart';
import '../../providers/user_provider.dart';
import '../../screens/emergency/emergency_screen.dart';
import 'widgets/confidence_indicator.dart';
import 'widgets/status_badge.dart';
import 'widgets/vital_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _emergencyPushed = false;

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(healthEventProvider);
    final user = ref.watch(userProvider);

    // Auto-push Emergency screen once per emergency event
    ref.listen<AsyncValue>(healthEventProvider, (_, next) {
      next.whenData((event) {
        if (event.isEmergency && !_emergencyPushed) {
          _emergencyPushed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context)
                .push(MaterialPageRoute(
                  builder: (_) => EmergencyScreen(event: event),
                  fullscreenDialog: true,
                ))
                .then((_) => _emergencyPushed = false);
          });
        }
        if (!event.isEmergency) _emergencyPushed = false;
      });
    });

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: eventAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text('Stream error: $e',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        data: (event) {
          final r = event.reading;
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // â”€â”€ App bar / greeting â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SliverAppBar(
                backgroundColor: AppColors.scaffold,
                elevation: 0,
                floating: true,
                expandedHeight: 100,
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 8),
                    child: _GreetingHeader(userName: user?.name ?? 'there'),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // â”€â”€ Overall status â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    StatusBadge(
                      status: event.overallStatus,
                      message: event.statusMessage,
                    ),
                    const SizedBox(height: 12),

                    // â”€â”€ Confidence score â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    ConfidenceIndicator(score: event.confidenceScore),
                    const SizedBox(height: 16),

                    // â”€â”€ Section label â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Vital Signs',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Updated ${DateFormatter.time(r.timestamp)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // â”€â”€ Vitals grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        VitalCard(
                          label: 'Heart Rate',
                          value: r.heartRate.toStringAsFixed(1),
                          unit: 'BPM',
                          status: event.hrStatus,
                          icon: Icons.favorite_rounded,
                          isPulsing: true,
                        ),
                        VitalCard(
                          label: 'SpOâ‚‚',
                          value: r.spO2.toStringAsFixed(1),
                          unit: '%',
                          status: event.spo2Status,
                          icon: Icons.water_drop_rounded,
                        ),
                        VitalCard(
                          label: 'HRV',
                          value: r.hrv.toStringAsFixed(1),
                          unit: 'ms',
                          status: event.hrvStatus,
                          icon: Icons.show_chart_rounded,
                        ),
                        VitalCard(
                          label: 'Respiration',
                          value: r.respirationRate.toStringAsFixed(1),
                          unit: 'br/min',
                          status: event.respirationStatus,
                          icon: Icons.air_rounded,
                        ),
                        VitalCard(
                          label: 'Activity',
                          value: _activityLabel(r.activity.name),
                          unit: '',
                          status: VitalStatus.normal,
                          icon: Icons.directions_run_rounded,
                        ),
                        VitalCard(
                          label: 'Fall Status',
                          value: r.fallDetected ? 'FALL!' : 'None',
                          unit: '',
                          status: r.fallDetected
                              ? VitalStatus.emergency
                              : VitalStatus.normal,
                          icon: Icons.warning_amber_rounded,
                        ),
                      ],
                    ),

                    // â”€â”€ Warning banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    if (event.overallStatus == VitalStatus.warning)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _WarningBanner(message: event.statusMessage),
                      ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _activityLabel(String raw) {
    switch (raw) {
      case 'lyingDown':
        return 'Lying Down';
      default:
        return raw[0].toUpperCase() + raw.substring(1);
    }
  }
}

// â”€â”€ Greeting header widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _GreetingHeader extends StatelessWidget {
  final String userName;
  const _GreetingHeader({required this.userName});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$_greeting, $userName',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                DateFormatter.date(DateTime.now()),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primaryLightest,
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Warning banner widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        border: Border.all(color: AppColors.warningBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
