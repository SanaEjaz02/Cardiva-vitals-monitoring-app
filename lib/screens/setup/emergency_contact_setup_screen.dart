import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/step_indicator.dart';
import '../../widgets/atoms/pill_widget.dart';
import '../../models/emergency_contact.dart';
import '../../router/app_router.dart';

class EmergencyContactSetupScreen extends StatefulWidget {
  const EmergencyContactSetupScreen({super.key});

  @override
  State<EmergencyContactSetupScreen> createState() =>
      _EmergencyContactSetupScreenState();
}

class _EmergencyContactSetupScreenState
    extends State<EmergencyContactSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _relationship;
  bool _smsEnabled = true;
  bool _locationEnabled = true;

  final List<EmergencyContact> _contacts = [];

  static const _relationships = [
    'Family', 'Friend', 'Doctor', 'Other'
  ];

  void _addContact() {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) return;
    setState(() {
      _contacts.add(EmergencyContact(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'demo',
        name: _nameCtrl.text,
        relation: _relationship ?? 'Family',
        phone: _phoneCtrl.text,
      ));
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      _relationship = null;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

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
                        child: StepIndicator(current: 3, total: 3)),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add emergency contact',
                        style: AppTextStyles.h1),
                    const SizedBox(height: 6),
                    Text(
                      'They will be alerted immediately if a critical emergency is detected.',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    // Form card
                    Container(
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
                      child: Column(
                        children: [
                          // Avatar
                          Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: AppColors.bgLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_add_outlined,
                                  color: AppColors.primary, size: 28),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameCtrl,
                            decoration:
                                const InputDecoration(hintText: 'Full name'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _relationship,
                            hint: Text('Relationship',
                                style: AppTextStyles.body
                                    .copyWith(color: AppColors.textSecondary)),
                            decoration: const InputDecoration(),
                            items: _relationships
                                .map((r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r,
                                          style: AppTextStyles.body),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _relationship = v),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: 'Phone number',
                              prefixText: '+92 ',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                                hintText: 'Email (optional)'),
                          ),
                          const SizedBox(height: 16),
                          _ToggleRow(
                            label: 'Notify via SMS',
                            value: _smsEnabled,
                            onChanged: (v) =>
                                setState(() => _smsEnabled = v),
                          ),
                          const SizedBox(height: 8),
                          _ToggleRow(
                            label: 'Share location',
                            value: _locationEnabled,
                            onChanged: (v) =>
                                setState(() => _locationEnabled = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Contacts list
                    ..._contacts.asMap().entries.map((entry) {
                      final i = entry.key;
                      final c = entry.value;
                      return Dismissible(
                        key: Key(c.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.danger),
                        ),
                        onDismissed: (_) =>
                            setState(() => _contacts.removeAt(i)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bgWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: const Border(
                              left: BorderSide(
                                  color: AppColors.primary, width: 3),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadowSm,
                                blurRadius: 12,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primaryBg,
                                child: Text(
                                  c.name[0].toUpperCase(),
                                  style: AppTextStyles.h2.copyWith(
                                      color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        style: AppTextStyles.h2),
                                    Text(c.phone,
                                        style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              PillWidget(
                                c.relation,
                                variant: PillVariant.primary,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (_contacts.length < 4)
                      OutlinedButton.icon(
                        onPressed: _addContact,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Contact'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRouter.dashboard,
                    (_) => false,
                  ),
                  child: const Text('Finish Setup →'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }
}
