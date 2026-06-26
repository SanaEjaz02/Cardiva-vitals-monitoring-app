import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../attendant/attendant_main_screen.dart';
import '../emergency/emergency_popup.dart';

// ── Theme mode helpers ─────────────────────────────────────────────────────
int _themeModeToIndex(ThemeMode m) {
  if (m == ThemeMode.light) return 1;
  if (m == ThemeMode.dark) return 2;
  return 0; // system
}

ThemeMode _indexToThemeMode(int i) {
  if (i == 1) return ThemeMode.light;
  if (i == 2) return ThemeMode.dark;
  return ThemeMode.system;
}

// ──────────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _hrMin = 55;
  double _hrMax = 100;
  double _spo2Min = 94;
  int _fallSensitivity = 1; // 0=Low, 1=Medium, 2=High
  bool _auto1122 = false;
  bool _encryptLocal = true;
  bool _cloudSync = true;
  bool _shareAnonymous = false;
  int _units = 0; // 0=Metric, 1=Imperial
  bool _haptics = true;

  Future<void> _pickReportTime() async {
    final settings = ref.read(settingsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.reportTime,
      helpText: 'Select daily report time',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      ref
          .read(settingsProvider.notifier)
          .setDailyReportTime(picked.hour, picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final themeIdx = _themeModeToIndex(settings.themeMode);
    final reportTimeLabel = settings.reportTimeLabel;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings & Privacy', style: AppTextStyles.h1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Section 0 — My Account
            const _SectionHeader('My Account'),
            _AccountCard(onRoleSwitch: _switchRole),
            const SizedBox(height: 16),
            // Section 1 — Alerts & Thresholds
            const _SectionHeader('Alerts & Thresholds'),
            _SettingsCard(key: const ValueKey('card-alerts'), children: [
              _SliderRow(
                label: 'Heart Rate Range',
                subtitle: '${_hrMin.toInt()}–${_hrMax.toInt()} bpm',
                child: RangeSlider(
                  values: RangeValues(_hrMin, _hrMax),
                  min: 40,
                  max: 180,
                  divisions: 140,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() {
                    _hrMin = v.start;
                    _hrMax = v.end;
                  }),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _SliderRow(
                label: 'SpO₂ Minimum',
                subtitle: '${_spo2Min.toInt()}%',
                child: Slider(
                  value: _spo2Min,
                  min: 85,
                  max: 100,
                  divisions: 15,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _spo2Min = v),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fall Detection Sensitivity',
                        style: AppTextStyles.body),
                    const SizedBox(height: 8),
                    _SegmentedControl(
                      options: const ['Low', 'Medium', 'High'],
                      selected: _fallSensitivity,
                      onSelect: (i) =>
                          setState(() => _fallSensitivity = i),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _ToggleRow(
                key: const ValueKey('toggle-autocall'),
                label: 'Auto-call 1122 (ETA > 20 min)',
                subtitle: 'Call emergency services automatically',
                value: _auto1122,
                onChanged: (v) => setState(() => _auto1122 = v),
              ),
            ]),
            const SizedBox(height: 16),
            // Section 2 — Guardians
            const _SectionHeader('Guardians'),
            _SettingsCard(key: const ValueKey('card-attendants'), children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medical_services_rounded,
                      color: AppColors.success, size: 18),
                ),
                title: Text('Manage Guardians', style: AppTextStyles.body),
                subtitle: Text(
                  'Guardians are linked via QR code and receive emergency alerts.',
                  style: AppTextStyles.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
                onTap: () => Navigator.pushNamed(
                    context, AppRouter.settingsAttendants),
              ),
              const Divider(height: 1, color: AppColors.divider),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_rounded,
                      color: AppColors.primary, size: 18),
                ),
                title: Text('My QR Code', style: AppTextStyles.body),
                subtitle: Text(
                  'Show your QR code for a guardian to scan and link.',
                  style: AppTextStyles.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
                onTap: () => Navigator.pushNamed(context, AppRouter.patientQr),
              ),
            ]),
            const SizedBox(height: 16),
            // Section 3 — Privacy & Data
            const _SectionHeader('Privacy & Data'),
            _SettingsCard(key: const ValueKey('card-privacy'), children: [
              _ToggleRow(
                key: const ValueKey('toggle-encrypt'),
                label: 'Encrypt local data',
                value: _encryptLocal,
                onChanged: (v) => setState(() => _encryptLocal = v),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _ToggleRow(
                key: const ValueKey('toggle-cloudsync'),
                label: 'Cloud sync',
                value: _cloudSync,
                onChanged: (v) => setState(() => _cloudSync = v),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _ToggleRow(
                key: const ValueKey('toggle-share'),
                label: 'Share anonymized data for research',
                value: _shareAnonymous,
                onChanged: (v) => setState(() => _shareAnonymous = v),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () => _confirmDelete(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Delete All Data'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            // Section 4 — App Preferences
            const _SectionHeader('App Preferences'),
            _SettingsCard(key: const ValueKey('card-prefs'), children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: AppTextStyles.body),
                    const SizedBox(height: 4),
                    Text(
                      'Changes take effect immediately across the entire app.',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 10),
                    _SegmentedControl(
                      options: const ['System', 'Light', 'Dark'],
                      selected: themeIdx,
                      onSelect: (i) => ref
                          .read(settingsProvider.notifier)
                          .setThemeMode(_indexToThemeMode(i)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Units', style: AppTextStyles.body),
                    const SizedBox(height: 8),
                    _SegmentedControl(
                      options: const ['Metric', 'Imperial'],
                      selected: _units,
                      onSelect: (i) => setState(() => _units = i),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _ToggleRow(
                key: const ValueKey('toggle-haptics'),
                label: 'Haptics',
                value: _haptics,
                onChanged: (v) => setState(() => _haptics = v),
              ),
              const Divider(height: 1, color: AppColors.divider),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.schedule_rounded,
                      color: AppColors.primary, size: 18),
                ),
                title: Text('Daily Report Time', style: AppTextStyles.body),
                subtitle: Text(
                  'Report generated & notification sent at this time',
                  style: AppTextStyles.caption,
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reportTimeLabel,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                onTap: _pickReportTime,
              ),
            ]),
            const SizedBox(height: 16),
            // Developer section — demo emergency flow
            const _SectionHeader('Developer'),
            _SettingsCard(key: const ValueKey('card-dev'), children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.dangerBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: AppColors.danger, size: 20),
                ),
                title:
                    Text('Run Demo Emergency', style: AppTextStyles.body),
                subtitle: Text(
                  'Walks through popup → alert sent with mocked data',
                  style: AppTextStyles.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
                onTap: () => _runDemoEmergency(context),
              ),
            ]),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _runDemoEmergency(BuildContext context) {
    EmergencyPopup.show(context, 'fall');
  }

  Future<void> _switchRole(UserRole newRole) async {
    final profile = ref.read(userProvider);
    if (profile == null) return;
    final updated = profile.copyWith(role: newRole);
    ref.read(userProvider.notifier).updateProfile(updated);

    final roleStr = newRole == UserRole.attendant ? 'attendant' : 'patient';
    // Save as top-level Firestore field so login always reads the right role
    FirestoreService.saveRole(roleStr).catchError((_) {});
    FirestoreService.saveProfile(updated.toJson()).catchError((_) {});

    if (!mounted) return;
    if (newRole == UserRole.attendant) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AttendantMainScreen()),
        (_) => false,
      );
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.dashboard,
        (_) => false,
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete all data?', style: AppTextStyles.h2),
        content: Text(
          'This will permanently remove all health records and preferences.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Delete',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ── Account card ───────────────────────────────────────────────────────────

class _AccountCard extends ConsumerWidget {
  final void Function(UserRole) onRoleSwitch;
  const _AccountCard({required this.onRoleSwitch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProvider);
    final uid = profile?.id ?? '—';
    final isAttendant = profile?.role == UserRole.attendant;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowLg, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Patient ID row (only shown for patients)
          if (!isAttendant) ...[
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.badge_rounded,
                    color: AppColors.primary, size: 18),
              ),
              title: Text('My Patient ID', style: AppTextStyles.body),
              subtitle: Text(
                uid,
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy_rounded,
                    color: AppColors.textSecondary, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: uid));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Patient ID copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
          ],
          // Role switch row
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isAttendant
                    ? AppColors.successBg
                    : AppColors.primaryBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAttendant
                    ? Icons.medical_services_rounded
                    : Icons.personal_injury_rounded,
                color: isAttendant ? AppColors.success : AppColors.primary,
                size: 18,
              ),
            ),
            title: Text('Current Role', style: AppTextStyles.body),
            subtitle: Text(
              isAttendant ? 'Guardian' : 'Patient',
              style: AppTextStyles.caption,
            ),
            trailing: TextButton(
              onPressed: () => _confirmSwitch(context, isAttendant),
              child: Text(
                isAttendant ? 'Switch to Patient' : 'Switch to Guardian',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSwitch(BuildContext context, bool currentlyAttendant) {
    final newRole =
        currentlyAttendant ? UserRole.patient : UserRole.attendant;
    final label = currentlyAttendant ? 'Patient' : 'Guardian';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Switch to $label?', style: AppTextStyles.h2),
        content: Text(
          currentlyAttendant
              ? 'You will return to the patient monitoring view.'
              : 'You will be taken to the Guardian portal where you can monitor a linked patient.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRoleSwitch(newRole);
            },
            child: Text('Switch to $label'),
          ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: AppTextStyles.caption
              .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm,
              blurRadius: 12,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: Text(label, style: AppTextStyles.body),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTextStyles.caption)
          : null,
      value: value,
      activeThumbColor: AppColors.primary,
      onChanged: onChanged,
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final Widget child;

  const _SliderRow({
    required this.label,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.body),
              Text(subtitle, style: AppTextStyles.caption),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  const _SegmentedControl({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: options.asMap().entries.map((e) {
          final active = e.key == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  e.value,
                  style: AppTextStyles.caption.copyWith(
                    color:
                        active ? Colors.white : AppColors.textSecondary,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
