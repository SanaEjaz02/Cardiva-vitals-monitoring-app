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

class _SheetBody extends ConsumerStatefulWidget {
  final ValueChanged<int>? onSwitchTab;
  final BuildContext callerContext;
  const _SheetBody({required this.callerContext, this.onSwitchTab});

  @override
  ConsumerState<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends ConsumerState<_SheetBody> {
  List<Attendant> _attendants = [];
  String? _localPhotoPath;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final prefs = await SharedPreferences.getInstance();

    final path = prefs.getString('profile_photo_path');
    final exists = path != null && await File(path).exists();

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
        _localPhotoPath = exists ? path : null;
        _attendants = atts;
      });
    }
  }

  ImageProvider? _photo(String? networkUrl) {
    if (_localPhotoPath != null) return FileImage(File(_localPhotoPath!));
    if (networkUrl != null) return NetworkImage(networkUrl);
    return null;
  }

  // ── Shared row builder (mirrors _ProfileRow in profile_screen.dart) ────────
  Widget _row({
    required IconData icon,
    required String label,
    String? value,
    Color? labelColor,
    VoidCallback? onTap,
    bool last = false,
    bool showChevron = true,
  }) {
    final color = labelColor ?? const Color(0xFF111827);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: labelColor != null
                        ? labelColor.withValues(alpha: 0.10)
                        : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      color: labelColor ?? AppColors.primary, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
                if (value != null)
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                if (showChevron) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded,
                      size: 18,
                      color: color.withValues(alpha: 0.3)),
                ],
              ],
            ),
          ),
        ),
        if (!last)
          const Divider(
              height: 1, indent: 62, endIndent: 16, color: Color(0xFFE5E7EB)),
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
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final networkUrl = user?.photoUrl ?? firebaseUser?.photoURL;
    final photo = _photo(networkUrl);

    final isConnected = vitals is AsyncData;
    final hr = vitals.valueOrNull?.heartRate;
    final spo2 = vitals.valueOrNull?.spO2;
    final bmi = user?.bmi;

    final providers =
        firebaseUser?.providerData.map((p) => p.providerId).toList() ?? [];
    final providerLabel = providers.contains('google.com')
        ? 'Google Account'
        : providers.contains('apple.com')
            ? 'Apple Account'
            : 'Email Account';
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
            borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
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

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
                    children: [
                      // ── Profile card (only card) ─────────────────
                      _profileCard(
                          photo, initial, name, email,
                          providerIcon, providerLabel, context),
                      const SizedBox(height: 16),

                      // ── Single grouped list (no card wrapper) ────
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Health rows
                            if (user != null) ...[
                              _row(
                                icon: Icons.straighten_rounded,
                                label: 'Height',
                                value: '${user.heightCm.toStringAsFixed(0)} cm',
                                showChevron: false,
                              ),
                              _row(
                                icon: Icons.monitor_weight_outlined,
                                label: 'Weight',
                                value: '${user.weightKg.toStringAsFixed(0)} kg',
                                showChevron: false,
                              ),
                              _row(
                                icon: Icons.bloodtype_outlined,
                                label: 'Blood Group',
                                value: user.bloodGroup.isNotEmpty
                                    ? user.bloodGroup
                                    : '—',
                                showChevron: false,
                              ),
                              _row(
                                icon: Icons.cake_outlined,
                                label: 'Age',
                                value: '${user.age} yrs',
                                showChevron: false,
                              ),
                              if (bmi != null)
                                _row(
                                  icon: Icons.area_chart_outlined,
                                  label: 'BMI',
                                  value: bmi.toStringAsFixed(1),
                                  showChevron: false,
                                ),
                            ],
                            // Device status
                            _row(
                              icon: isConnected
                                  ? Icons.sensors_rounded
                                  : Icons.sensors_off_rounded,
                              label: 'Device',
                              value: isConnected
                                  ? (hr != null
                                      ? '${hr.toStringAsFixed(0)} bpm · ${spo2?.toStringAsFixed(0) ?? '—'}%'
                                      : 'Connected')
                                  : 'No sensor',
                              showChevron: false,
                            ),
                            // Guardians
                            _row(
                              icon: Icons.people_outline_rounded,
                              label: 'Guardians',
                              value: _attendants.isEmpty
                                  ? 'None'
                                  : '${_attendants.length}',
                              onTap: () {
                                final ctx = widget.callerContext;
                                Navigator.pop(context);
                                Navigator.pushNamed(
                                    ctx, AppRouter.settingsAttendants)
                                    .then((_) {
                                  if (ctx.mounted) {
                                    ProfileQuickSheet.show(ctx,
                                        onSwitchTab: widget.onSwitchTab);
                                  }
                                });
                              },
                            ),
                            // View full profile
                            _row(
                              icon: Icons.person_outline_rounded,
                              label: 'View Full Profile',
                              onTap: () {
                                final ctx = widget.callerContext;
                                final switchTab = widget.onSwitchTab;
                                Navigator.pop(context);
                                Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                      builder: (_) => const ProfileScreen()),
                                ).then((_) {
                                  if (ctx.mounted) {
                                    ProfileQuickSheet.show(ctx,
                                        onSwitchTab: switchTab);
                                  }
                                });
                              },
                            ),
                            // Settings
                            _row(
                              icon: Icons.settings_outlined,
                              label: 'Settings',
                              onTap: () {
                                final ctx = widget.callerContext;
                                Navigator.pop(context);
                                Navigator.pushNamed(ctx, AppRouter.settings)
                                    .then((_) {
                                  if (ctx.mounted) {
                                    ProfileQuickSheet.show(ctx,
                                        onSwitchTab: widget.onSwitchTab);
                                  }
                                });
                              },
                            ),
                            // Log out
                            _row(
                              icon: Icons.logout_rounded,
                              label: 'Log Out',
                              labelColor: AppColors.danger,
                              showChevron: false,
                              last: true,
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

  Widget _profileCard(
    ImageProvider? photo,
    String initial,
    String name,
    String email,
    IconData providerIcon,
    String providerLabel,
    BuildContext context,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar + name
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF48CAE4), Color(0xFF90E0EF)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 26,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          // Provider row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(providerIcon,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  providerLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          // Edit profile
          InkWell(
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16)),
            onTap: () {
              final ctx = widget.callerContext;
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 120), () {
                if (ctx.mounted) ProfileScreen.openEditSheet(ctx, ref);
              });
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0FDF4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: AppColors.success, size: 17),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: Color(0xFF9CA3AF)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
