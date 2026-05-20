import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendant.dart';
import '../providers/user_provider.dart';
import '../providers/vital_provider.dart';
import '../router/app_router.dart';
import '../screens/profile/profile_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

// Dashboard-matching dark gradient colours
const _kNavy1 = Color(0xFF050A2E);
const _kNavy2 = Color(0xFF0A2F5A);
const _kNavy3 = Color(0xFF0D4F78);

/// Slides in from the right — call via [ProfileQuickSheet.show].
class ProfileQuickSheet {
  static void show(BuildContext context, {ValueChanged<int>? onSwitchTab}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => _SheetBody(
        onSwitchTab: onSwitchTab,
        callerContext: context,
      ),
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SheetBody extends ConsumerStatefulWidget {
  final ValueChanged<int>? onSwitchTab;
  final BuildContext callerContext;
  const _SheetBody({required this.callerContext, this.onSwitchTab});

  @override
  ConsumerState<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends ConsumerState<_SheetBody> {
  List<Attendant> _attendants = [];
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final prefs = await SharedPreferences.getInstance();

    // Photo
    final path = prefs.getString('profile_photo_path');
    final exists = path != null && await File(path).exists();

    // Attendants
    final raw = prefs.getString('attendants_${uid}_v1');
    List<Attendant> atts = [];
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        atts = list
            .map((j) => Attendant.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _photoPath = exists ? path : null;
        _attendants = atts;
      });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ImageProvider? _resolvePhoto(String? profilePhotoUrl) {
    if (_photoPath != null) return FileImage(File(_photoPath!));
    if (profilePhotoUrl != null) return NetworkImage(profilePhotoUrl);
    final googleUrl =
        FirebaseAuth.instance.currentUser?.photoURL;
    if (googleUrl != null) return NetworkImage(googleUrl);
    return null;
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      );

  Widget _listRow({
    required IconData icon,
    required String label,
    String? value,
    Color labelColor = const Color(0xFF111827),
    Color iconBgColor = const Color(0xFFEFF6FF),
    Color iconColor = AppColors.primary,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: labelColor,
                        ),
                      ),
                      if (value != null)
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: labelColor.withValues(alpha: 0.3),
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
              height: 1,
              indent: 56,
              endIndent: 14,
              color: Color(0xFFE5E7EB)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final vitals = ref.watch(latestReadingProvider);
    final firebaseUser = FirebaseAuth.instance.currentUser;

    final name = user?.name ?? firebaseUser?.displayName ?? 'Patient';
    final email = user?.email ?? firebaseUser?.email ?? '';
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : 'P';

    final networkPhoto = user?.photoUrl ?? firebaseUser?.photoURL;
    final photo = _resolvePhoto(networkPhoto);

    final isConnected = vitals is AsyncData;
    final hr = vitals.valueOrNull?.heartRate;
    final spo2 = vitals.valueOrNull?.spO2;
    final bmi = user?.bmi;

    // Provider label (Google / Email etc.)
    final providers =
        firebaseUser?.providerData.map((p) => p.providerId).toList() ?? [];
    final providerLabel = providers.contains('google.com')
        ? 'Signed in with Google'
        : providers.contains('apple.com')
            ? 'Signed in with Apple'
            : 'Signed in with Email';
    final providerIcon = providers.contains('google.com')
        ? Icons.g_mobiledata_rounded
        : providers.contains('apple.com')
            ? Icons.apple
            : Icons.email_outlined;

    final panelWidth = MediaQuery.of(context).size.width * 0.72;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: panelWidth,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_kNavy1, _kNavy2, _kNavy3],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius:
                BorderRadius.horizontal(left: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 14, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white60, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'My Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable content ───────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
                    children: [
                      // ── Profile card ────────────────────────────────
                      _card(
                        child: Column(
                          children: [
                            // Avatar + name row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  14, 14, 14, 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(colors: [
                                        Color(0xFF48CAE4),
                                        Color(0xFF90E0EF),
                                      ]),
                                    ),
                                    child: CircleAvatar(
                                      radius: 28,
                                      backgroundColor: _kNavy2,
                                      backgroundImage: photo,
                                      child: photo == null
                                          ? Text(
                                              initial,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (email.isNotEmpty)
                                          Text(
                                            email,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6B7280),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(
                                height: 1, color: Color(0xFFE5E7EB)),
                            // Provider row
                            _listRow(
                              icon: providerIcon,
                              label: providerLabel,
                              iconBgColor: const Color(0xFFEFF6FF),
                              iconColor: AppColors.primary,
                              trailing: const SizedBox.shrink(),
                              showDivider: true,
                            ),
                            // Edit profile row
                            _listRow(
                              icon: Icons.edit_outlined,
                              label: 'Edit Profile',
                              iconBgColor: const Color(0xFFF0FDF4),
                              iconColor: AppColors.success,
                              trailing: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: AppColors.success
                                    .withValues(alpha: 0.7),
                              ),
                              showDivider: false,
                              onTap: () {
                                final ctx = widget.callerContext;
                                Navigator.pop(context);
                                Future.delayed(
                                  const Duration(milliseconds: 120),
                                  () {
                                    if (ctx.mounted) {
                                      ProfileScreen.openEditSheet(
                                          ctx, ref);
                                    }
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Health Profile ──────────────────────────────
                      _sectionLabel('Health Profile'),
                      _card(
                        padding: const EdgeInsets.all(14),
                        child: user == null
                            ? const Text(
                                'No profile data yet.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF)),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _VitalChip(
                                    icon: Icons.straighten_rounded,
                                    label: 'Height',
                                    value:
                                        '${user.heightCm.toStringAsFixed(0)} cm',
                                  ),
                                  _VitalChip(
                                    icon: Icons.monitor_weight_outlined,
                                    label: 'Weight',
                                    value:
                                        '${user.weightKg.toStringAsFixed(0)} kg',
                                  ),
                                  _VitalChip(
                                    icon: Icons.bloodtype_outlined,
                                    label: 'Blood',
                                    value: user.bloodGroup.isNotEmpty
                                        ? user.bloodGroup
                                        : '—',
                                  ),
                                  _VitalChip(
                                    icon: Icons.cake_outlined,
                                    label: 'Age',
                                    value: '${user.age} yrs',
                                  ),
                                  if (bmi != null)
                                    _VitalChip(
                                      icon: Icons.area_chart_outlined,
                                      label: 'BMI',
                                      value: bmi.toStringAsFixed(1),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),

                      // ── Device ─────────────────────────────────────
                      _sectionLabel('Device'),
                      _card(
                        child: _listRow(
                          icon: isConnected
                              ? Icons.sensors_rounded
                              : Icons.sensors_off_rounded,
                          label: isConnected
                              ? 'Sensor Connected'
                              : 'No Sensor Data',
                          value: isConnected && hr != null
                              ? '${hr.toStringAsFixed(0)} bpm  ·  ${spo2?.toStringAsFixed(0) ?? '--'}% SpO₂'
                              : null,
                          iconBgColor: isConnected
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF3F4F6),
                          iconColor: isConnected
                              ? AppColors.success
                              : const Color(0xFF9CA3AF),
                          trailing: const SizedBox.shrink(),
                          showDivider: false,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Attendants ──────────────────────────────────
                      Row(
                        children: [
                          Expanded(child: _sectionLabel('Attendants')),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context,
                                  AppRouter.settingsAttendants);
                            },
                            child: const Text(
                              'Manage',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF90E0EF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _card(
                        child: _attendants.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: Text(
                                  'No attendants added.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              )
                            : Column(
                                children:
                                    _attendants.take(3).map((a) {
                                  final isLast =
                                      a == _attendants.take(3).last;
                                  return _listRow(
                                    icon: Icons.person_outlined,
                                    label: a.name,
                                    value: a.relationship,
                                    showDivider: !isLast,
                                    iconBgColor:
                                        const Color(0xFFEFF6FF),
                                    iconColor: AppColors.primary,
                                    trailing: a.notifyViaSms
                                        ? const Icon(
                                            Icons.sms_outlined,
                                            size: 14,
                                            color: AppColors.success,
                                          )
                                        : const SizedBox.shrink(),
                                  );
                                }).toList(),
                              ),
                      ),
                      const SizedBox(height: 20),

                      // ── Quick Actions ───────────────────────────────
                      _card(
                        child: Column(
                          children: [
                            _listRow(
                              icon: Icons.person_outline_rounded,
                              label: 'View Full Profile',
                              onTap: () {
                                Navigator.pop(context);
                                widget.onSwitchTab?.call(4);
                              },
                            ),
                            _listRow(
                              icon: Icons.settings_outlined,
                              label: 'Settings',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(
                                    context, AppRouter.settings);
                              },
                            ),
                            _listRow(
                              icon: Icons.logout_rounded,
                              label: 'Log Out',
                              labelColor: AppColors.danger,
                              iconBgColor: const Color(0xFFFEF2F2),
                              iconColor: AppColors.danger,
                              showDivider: false,
                              onTap: () async {
                                Navigator.pop(context);
                                await AuthService.signOut();
                                if (context.mounted) {
                                  Navigator.of(context)
                                      .pushNamedAndRemoveUntil(
                                          AppRouter.auth, (_) => false);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _VitalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _VitalChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
