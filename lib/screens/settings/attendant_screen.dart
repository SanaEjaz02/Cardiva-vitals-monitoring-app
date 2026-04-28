import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/atoms/pill_widget.dart';
import '../../models/attendant.dart';

class AttendantScreen extends StatefulWidget {
  const AttendantScreen({super.key});

  @override
  State<AttendantScreen> createState() => _AttendantScreenState();
}

class _AttendantScreenState extends State<AttendantScreen> {
  final List<Attendant> _attendants = [
    const Attendant(
      id: '1',
      name: 'Ayesha Khan',
      relationship: 'Family',
      phone: '+92-333-1234567',
      email: 'ayesha@email.com',
      notifyViaSms: true,
      shareLocation: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Attendants', style: AppTextStyles.h1),
        actions: [
          TextButton(
            onPressed: () => _showAttendantSheet(context, null),
            child: Text('Add',
                style: AppTextStyles.body.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Info card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
              ),
              child: Text(
                'Attendants can monitor your vitals and will be notified during emergencies. Different from emergency contacts.',
                style: AppTextStyles.caption,
              ),
            ),
            const SizedBox(height: 16),
            if (_attendants.isEmpty)
              _EmptyState(
                  onAdd: () => _showAttendantSheet(context, null))
            else
              ..._attendants.asMap().entries.map((e) {
                final i = e.key;
                final att = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AttendantCard(
                    attendant: att,
                    onEdit: () => _showAttendantSheet(context, att),
                    onDelete: () => _confirmDelete(context, i),
                    onToggleSms: (v) => setState(() {
                      _attendants[i] =
                          att.copyWith(notifyViaSms: v);
                    }),
                    onToggleLocation: (v) => setState(() {
                      _attendants[i] =
                          att.copyWith(shareLocation: v);
                    }),
                  ),
                );
              }),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _showAttendantSheet(BuildContext context, Attendant? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AttendantSheet(
        existing: existing,
        onSave: (a) {
          setState(() {
            if (existing != null) {
              final i = _attendants.indexWhere((x) => x.id == existing.id);
              if (i >= 0) _attendants[i] = a;
            } else {
              _attendants.add(a);
            }
          });
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove attendant?', style: AppTextStyles.h2),
        content: Text(
          'They will no longer receive emergency alerts.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _attendants.removeAt(index));
            },
            child: Text('Remove',
                style: AppTextStyles.body.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _AttendantCard extends StatelessWidget {
  final Attendant attendant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleSms;
  final ValueChanged<bool> onToggleLocation;

  const _AttendantCard({
    required this.attendant,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSms,
    required this.onToggleLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowSm, blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryBg,
                child: Text(attendant.initials,
                    style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attendant.name, style: AppTextStyles.h2),
                    Text(attendant.relationship,
                        style: AppTextStyles.caption),
                    Text(attendant.phone, style: AppTextStyles.caption),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.primary, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PillWidget(
                attendant.notifyViaSms ? 'SMS ON' : 'SMS OFF',
                variant: attendant.notifyViaSms
                    ? PillVariant.success
                    : PillVariant.outline,
              ),
              const SizedBox(width: 8),
              PillWidget(
                attendant.shareLocation ? 'Location ON' : 'Location OFF',
                variant: attendant.shareLocation
                    ? PillVariant.success
                    : PillVariant.outline,
              ),
              const Spacer(),
              Switch.adaptive(
                value: attendant.notifyViaSms,
                onChanged: onToggleSms,
                activeColor: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendantSheet extends StatefulWidget {
  final Attendant? existing;
  final ValueChanged<Attendant> onSave;

  const _AttendantSheet({this.existing, required this.onSave});

  @override
  State<_AttendantSheet> createState() => _AttendantSheetState();
}

class _AttendantSheetState extends State<_AttendantSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  String? _relationship;
  late bool _sms;
  late bool _location;

  static const _rels = [
    'Family', 'Friend', 'Doctor', 'Caregiver', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name);
    _phoneCtrl = TextEditingController(text: widget.existing?.phone);
    _emailCtrl = TextEditingController(text: widget.existing?.email);
    _relationship = widget.existing?.relationship;
    _sms = widget.existing?.notifyViaSms ?? true;
    _location = widget.existing?.shareLocation ?? true;
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
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
      decoration: const BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.accentTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.existing == null ? 'Add Attendant' : 'Edit Attendant',
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: 'Full name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _relationship,
                  hint: Text('Relationship',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary)),
                  decoration: const InputDecoration(),
                  items: _rels
                      .map((r) => DropdownMenuItem(
                          value: r, child: Text(r, style: AppTextStyles.body)))
                      .toList(),
                  onChanged: (v) => setState(() => _relationship = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'Phone number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      hintText: 'Email (optional)'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Notify via SMS', style: AppTextStyles.body),
                    Switch.adaptive(
                      value: _sms,
                      onChanged: (v) => setState(() => _sms = v),
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Share live location', style: AppTextStyles.body),
                    Switch.adaptive(
                      value: _location,
                      onChanged: (v) => setState(() => _location = v),
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_nameCtrl.text.isEmpty) return;
                      final att = Attendant(
                        id: widget.existing?.id ?? const Uuid().v4(),
                        name: _nameCtrl.text,
                        relationship: _relationship ?? 'Family',
                        phone: _phoneCtrl.text,
                        email: _emailCtrl.text.isEmpty
                            ? null
                            : _emailCtrl.text,
                        notifyViaSms: _sms,
                        shareLocation: _location,
                      );
                      widget.onSave(att);
                      Navigator.pop(context);
                    },
                    child: const Text('Save Attendant'),
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.person_add_outlined,
              size: 64, color: AppColors.accentTint),
          const SizedBox(height: 12),
          Text('No attendants added yet', style: AppTextStyles.caption),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAdd,
            child: const Text('Add Attendant'),
          ),
        ],
      ),
    );
  }
}
